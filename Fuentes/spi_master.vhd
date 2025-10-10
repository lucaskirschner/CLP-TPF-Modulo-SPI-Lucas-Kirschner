-------------------------------------------------------------------------------
-- Descripción:  SPI (Interfaz Periferica Serial) Maestro
--               Con capacidad para un único Chip Select/Slave Select
--
--               Permite la transferencia síncrona de datos en palabras de 
--               longitud configurable de 8 o 16 bits, pudiendo seleccionar
--               además el orden de transferencia de los bits.
--
--               Soporta los cuatro modos estándar de operación SPI:
--               Modo | Polaridad de reloj (CPOL)  | Fase de reloj (CPHA)
--                0   |             0              |          0
--                1   |             0              |          1
--                2   |             1              |          0
--                3   |             1              |          1
--
-- Nota:          clk_i debe ser al menos 2 veces más rápido que spi_clk_i.
--
-- Parámetros: 
--               SPI_MODE : Define el modo de operación SPI (0, 1, 2 o 3).
--
--               DATA_SIZE : Define la longitud de palabra de datos, 
--               pudiendo seleccionarse entre 8 o 16 bits.
--
--               SPI_CLK_PRE : Ajusta la frecuencia de spi_clk_o. 
--               spi_clk_o se deriva de spi_clk_i. Se establece como un número 
--               entero de ciclos de reloj por cada medio bit de datos SPI.
--               Ejemplo: con spi_clk_i = 100 MHz y SPI_CLK_PRE = 2, 
--               se obtiene spi_clk_o = 25 MHz.
--
--               CS: Este módulo controla automáticamente la señal CS, 
--               manteniéndola baja durante la transferencia y 
--               liberándola al finalizar la comunicación.
-------------------------------------------------------------------------------

-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_master is
  generic(
    SPI_DATA_SIZE : natural  := SPI_DATASIZE_8BIT;
    SPI_MODE      : natural  := SPI_MODE_0;
    SPI_FIRST_BIT : natural  := SPI_FIRSTBIT_MSB;
    SPI_CLK_PRE   : natural  := SPI_CLK_PRESCALER_12_5MBPS
  );
    
  port(
    -- Senales de control
    rst_i     : in std_logic;                                            -- reset activo en bajo
    clk_i     : in std_logic;                                            -- reloj del sistema
    
    -- Senales MOSI
    tx_data_i : in  std_logic_vector(SPI_DATA_SIZE-1 downto 0);          -- dato de entrada a transmitir por spi_mosi_o
    tx_dv_i   : in  std_logic;                                           -- pulso: indica dato valido en tx_data_i
    tx_rdy_o  : out std_logic;                                           -- listo para aceptar un nuevo dato
   
    -- Senales MISO
    rx_data_o : out std_logic_vector(SPI_DATA_SIZE-1 downto 0);          -- dato de salida recibido por spi_miso_i
    rx_dv_o   : out std_logic;                                           -- pulso: dato de entrada listo en rx_data_o
    
    -- Interfaz SPI
    spi_clk_o   : out std_logic;                                         -- linea SCK
    spi_mosi_o  : out std_logic;                                         -- linea MOSI (Master Out Slave In)
    spi_miso_i  : in  std_logic;                                         -- linea MISO (Master In Slave Out)
    spi_cs_o    : out std_logic                                          -- linea CS (Chip Select)
  );   
end entity spi_master;

-- Cuerpo de arquitectura
architecture spi_master_arq of spi_master is
	-- Parte declarativa
	
	-- Constantes
	constant HIGH_INDEX      : natural := SPI_DATA_SIZE - 1;               -- indice superior para cuenta ascendente en modo MSB FIRST BIT
	constant LOW_INDEX       : natural := 0;                               -- indice inferior para cuenta descendente en modo LSB FIRST BIT
	
	-- Derivacion de modo
	signal cpol_c : std_logic;                                             -- polaridad de SCK (estado en modo idle)
  signal cpha_c : std_logic;                                             -- fase de sck para muestreo/actualizacion
	
	-- Generacion de SCK y flancos
	signal spi_clk_count_s   : natural range 0 to (2*SPI_CLK_PRE)-1;       -- cuenta numero de ciclos para division de scl_i
	signal spi_clk_s         : std_logic;                                  -- sck interno
	signal spi_clk_edges_s   : natural range 0 to 2*SPI_DATA_SIZE;         -- cuenta flancos restantes para finalizar la transmision/recepcion
	signal leading_edge_s    : std_logic;                                  -- flanco de sck desde idle a estado activo segun SPI_MODE seleccionado
	signal trailing_edge_s   : std_logic;                                  -- flanco de sck desde estado activo a idle segun SPI_MODE seleccionado
	
	-- Control de transmision
	signal tx_data_s         : std_logic_vector(SPI_DATA_SIZE-1 downto 0); -- vector local para 'congelar' el dato a transmitir
	signal tx_dv_s           : std_logic;                                  -- senal local para retrasar un ciclo el pulso dato valido de entrada
	signal tx_rdy_s          : std_logic;                                  -- senal local para el manejo del ready y actualizarlo en el mismo ciclo al finalizar la transferencia
	signal tx_bit_count_s    : natural range 0 to HIGH_INDEX;              -- contador de bits transmitidos
	signal tx_mosi_s         : std_logic;                                  -- registro interno para actualización inmediata de spi_mosi_o
	
	-- Control de recepcion
	signal rx_data_s         : std_logic_vector(SPI_DATA_SIZE-1 downto 0); -- vector local para armar el vector de datos de entrada
	signal rx_bit_count_s    : natural range 0 to HIGH_INDEX;              -- contador de bits recibidos
	
begin
	-- Parte descriptiva
	cpol_c <= '1' when (SPI_MODE = 2) or (SPI_MODE = 3) else '0';          -- determina polaridad del reloj segun SPI_MODE seleccionado
	cpha_c <= '1' when (SPI_MODE = 1) or (SPI_MODE = 3) else '0';          -- determina fase del reloj segun SPI_MODE seleccionado
	
	
	-- Funcion:  Realiza la division del reloj clk_i de entrada 
	--           y genera los flancos que se usaran para la comunicacion
	edge_indicator : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   spi_clk_count_s <=  0;                            -- configuro el estado de arranque de sck
	   spi_clk_s       <= cpol_c;
	   spi_clk_edges_s <=  0;
	   leading_edge_s  <= '0';
	   trailing_edge_s <= '0';
	   tx_rdy_s        <= '1';                           -- asumo que se mantiene listo para recibir un nuevo dato
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   leading_edge_s  <= '0';                           -- limpia valores por defecto
	   trailing_edge_s <= '0';                           -- limpia valores por defecto
	   if tx_dv_s = '1' and tx_rdy_s = '1' then          -- cuando llega el pulso de dato válido y el modulo esta listo para recibirlo  
	     tx_rdy_s <= '0';                                -- el modulo se declara ocupado
	     spi_clk_edges_s <= 2*SPI_DATA_SIZE;             -- y programa los flancos de sck necesarios para completar la transmision/recepcion
	   elsif spi_clk_edges_s > 0 then                    -- mientras haya flancos pendientes programados
	     tx_rdy_s <= '0';                                -- el modulo se matiene ocupado
	     if spi_clk_count_s = SPI_CLK_PRE-1 then         -- si complete medio periodo de spi_clk
	       spi_clk_count_s <= spi_clk_count_s + 1;       -- incremento el contador de ciclos
	       spi_clk_edges_s <= spi_clk_edges_s - 1;       -- decremento numero de flancos restantes
	       leading_edge_s  <= '1';                       -- indico transicion de estado de sck: idle => activo
	       spi_clk_s       <= not spi_clk_s;             -- toggleo sck interno
	     elsif spi_clk_count_s = (2*SPI_CLK_PRE)-1 then  -- si complete un periodo de spi_clk
	       spi_clk_count_s <= 0;                         -- reinicio contador de ciclos
	       spi_clk_edges_s <= spi_clk_edges_s - 1;       -- decremento numero de flancos restantes
	       trailing_edge_s <= '1';                       -- indico transicion de estado de sck: activo => idle
	       spi_clk_s       <= not spi_clk_s;             -- toggleo sck interno
	     else                                            -- sino
	       spi_clk_count_s <= spi_clk_count_s + 1;       -- incremento el contador de ciclos
	     end if;                                         -- si ya no hay flancos pendientes
	   else
	     tx_rdy_s <= '1';                                -- el modulo vuelve a estar libre
	   end if;
	 end if;
	end process edge_indicator;
	
	
	-- Funcion:  Latch del dato de entrada.
  --           Asegura que el byte quede estable durante toda la transferencia
  --           por mas que la entrada cambie y genera un pulso alineado (retardado 
  --           1 clk_i) para la logica MOSI/MISO.
	data_latch : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   tx_data_s <= (others => '0');                     -- limpia el buffer local de tx (dato estable interno)
	   tx_dv_s <= '0';                                   -- borra el pulso de "dato valido" interno
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_dv_i = '1' and tx_rdy_s = '1' then          -- cuando la entidad superior afirma un dato valido
	     tx_dv_s   <= tx_dv_i;                           -- registra tx_dv_i: genera un pulso 1 clk más tarde
	     tx_data_s <= tx_data_i;                         -- crea una copia local del dato a transmitir
	   else                                              -- sino
	     tx_dv_s   <= '0';                               -- indica que no hay datos de entrada validos
	   end if;
	 end if;
	end process data_latch;
	
	-- Funcion:  Genera la salida MOSI bit a bit
  --           Compatible con CPHA=0 y CPHA=1 usando los strobes de flanco.
	mosi_transfer : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   tx_mosi_s     <= '0';                             -- la salida permanece inactiva
	   
	   if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then          -- si va primero el MSB
	     tx_bit_count_s <= HIGH_INDEX;                   -- indice = extremo superior
     else                                              -- si va primero el LSB
       tx_bit_count_s <= LOW_INDEX;                    -- indice = extremo inferior
     end if;                      
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_rdy_s = '1' then                            -- si hay un dato valido de entrada y es el primer ciclo
	     
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then        -- asegura precarga de indice
	       tx_bit_count_s <= HIGH_INDEX;
       else
         tx_bit_count_s <= LOW_INDEX;
       end if;
	   
	     if tx_dv_s = '1' and cpha_c = '0' then          -- en el modo CPHA = 0 el esclavo muestrea el primer bit en el primer flanco,
	       tx_mosi_s <= tx_data_s(tx_bit_count_s);       -- por lo que debe arrancar listo
	     
	       if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then      -- decrementa o incrementa indice segun modo
	         if tx_bit_count_s > 0 then
	           tx_bit_count_s <= tx_bit_count_s-1;
	         end if;
         else
           if tx_bit_count_s < HIGH_INDEX then
             tx_bit_count_s <= tx_bit_count_s+1;
           end if;
         end if;
         
       elsif tx_rdy_s = '1' then                        -- si no llego un nuenvo dato pero esta ready
         tx_mosi_s <= '0';                              -- MOSI permanece en estado idle
       end if;
       
	   elsif (leading_edge_s = '1' and cpha_c = '1')      -- en CPHA = 1, se lee dato en trailing y se actualiza en leading
	      or (trailing_edge_s = '1' and cpha_c = '0') then-- en CPHA = 0, se lee dato en leading y actualiza en trailing
	     
	     tx_mosi_s <= tx_data_s(tx_bit_count_s);          -- actualiza el dato
	     
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then         -- decrementa o incrementa indice segun modo
	       if tx_bit_count_s > 0 then
	         tx_bit_count_s <= tx_bit_count_s-1;
	       end if;
       else
         if tx_bit_count_s < HIGH_INDEX then
          tx_bit_count_s <= tx_bit_count_s+1;
         end if;
       end if;
	   end if;
	 end if;
	end process mosi_transfer;
	
	-- Funcion:  Captura datos de MISO y arma el byte recibido.
  --           Emite un pulso rx_dv_o por 1 clk cuando el byte recibido esta listo.
	miso_capture : process(clk_i, rst_i)
	variable rx_data_v : std_logic_vector(SPI_DATA_SIZE-1 downto 0); -- vector variable de dato de entrada
	begin
	 if rst_i = '0' then                                             -- mientras se mantenga en estado reset
	   rx_data_s       <= (others => '0');
	   rx_data_o       <= (others => '0');
	   rx_dv_o         <= '0';
	   
	   if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then                      -- si va primero el MSB
	     rx_bit_count_s <= HIGH_INDEX;                               -- indice = extremo superior
     else                                                          -- si va primero el LSB
       rx_bit_count_s <= LOW_INDEX;                                -- indice = extremo inferior
     end if; 
	   
	 elsif rising_edge(clk_i) then                                   -- sino esta en reset, espera flanco ascendente de clk_i
	   rx_dv_o <= '0';
	   if tx_rdy_s = '1' then
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then                    -- asegura precarga de indice
	       rx_bit_count_s <= HIGH_INDEX;
       else
         rx_bit_count_s <= LOW_INDEX;
       end if;
	     
	   elsif (leading_edge_s = '1' and cpha_c = '0')                 -- en CPHA = 0, se lee dato en leading y actualiza en trailing
	     or (trailing_edge_s = '1' and cpha_c = '1') then            -- en CPHA = 1, se lee dato en trailing y se actualiza en leading
	     
	     rx_data_v := rx_data_s;                                     -- tomo el ultimo vector de datos. rx_data_s usada como shift register
	     rx_data_v(rx_bit_count_s) := spi_miso_i;                    -- actualizo con el ultimo bit recibido
	     rx_data_s(rx_bit_count_s) <= spi_miso_i;
	     
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then                    -- segun el modo de transferencia de bits
	       if rx_bit_count_s = 0 then                                -- si primero MSB e indice llego a cero
	         rx_data_o <= rx_data_v;                                 -- actualizo la salida de datos
	         rx_dv_o <= '1';                                         -- indico el dato valido
	       else 
	         rx_bit_count_s <= rx_bit_count_s - 1;                   -- si todavia no termino la recepcion, decremento el indice
	       end if;
	     else
	       if rx_bit_count_s = HIGH_INDEX then                       -- si primero LSB e indice llego al maximo
	         rx_data_o <= rx_data_v;                                 -- actualizo la salida de datos en el mismo ciclo gracias al uso de la variable
	         rx_dv_o <= '1';                                         -- indico el dato valido
	       else
	         rx_bit_count_s <= rx_bit_count_s + 1;                   -- si todavia no termino la recepcion, incremento el indice
	       end if;
	     end if;
	   end if;
	 end if;
	end process miso_capture;
	
	-- Funcion: anade un retardo de reloj para alinear senales
	clk_delay : process(clk_i, rst_i)
	begin
	  if rst_i = '0' then                             -- mientras se mantenga en estado reset
	    spi_clk_o <= cpol_c;                          -- en reset, deja el SCK externo en su nivel idle (CPOL)
	  elsif rising_edge(clk_i) then                   -- sino esta en reset,
	    spi_clk_o <= spi_clk_s;                       -- sincroniza el reloj de salida con el generado
	  end if;
	end process clk_delay;
	
	-- Habilita/deshabilita el pin chip select
	spi_cs_o <= '0' when (tx_rdy_s = '0') else '1';
	-- Actualiza estado de salida ready
	tx_rdy_o <= tx_rdy_s;
	-- Actualiza estado de salida mosi
	spi_mosi_o <= '0' when (tx_rdy_s = '1') else tx_mosi_s;
	
end architecture spi_master_arq;