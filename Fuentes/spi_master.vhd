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
    SPI_CLK_POL   : natural  := SPI_POLARITY_LOW;                -- no implementado en esta version, se derivan desde SPI_MODE
    SPI_CLK_PHASE : natural  := SPI_PHASE_1EDGE;                 -- no implementado en esta version, se derivan desde SPI_MODE
    SPI_CLK_PRE   : natural  := SPI_CLK_PRESCALER_125KBPS;
    SPI_FIRST_BIT : natural  := SPI_FIRSTBIT_MSB
  );
    
  port(
    -- Senales de control
    rst_i     : in std_logic;                                        -- reset del modulo activo en bajo
    clk_i     : in std_logic;                                        -- reloj principal del sistema
    
    -- Senales MOSI
    tx_data_i : in  std_logic_vector(SPI_DATA_SIZE-1 downto 0);      -- dato a transmitir por MOSI
    tx_dv_i   : in  std_logic;                                       -- pulso que indica dato valido en tx_data_i
    tx_rdy_o  : out std_logic;                                       -- indica que el módulo puede aceptar un nuevo dato
    
    -- Senales MISO
    rx_data_o : out std_logic_vector(SPI_DATA_SIZE-1 downto 0);      -- dato recibido desde MISO
    rx_dv_o   : out std_logic;                                       -- pulso que indica dato recibido valido
    
    -- Interfaz SPI
    spi_clk_o   : out std_logic;                                     -- senal de reloj SPI generada por el maestro
    spi_mosi_o  : out std_logic;                                     -- linea MOSI (Master Out Slave In)
    spi_miso_i  : in  std_logic;                                     -- linea MISO (Master In Slave Out)
    spi_cs_o    : out std_logic                                      -- senal de chip select activa en bajo
  );   
end entity spi_master;

-- Cuerpo de arquitectura
architecture spi_master_arq of spi_master is
	-- Parte declarativa
	signal CPOL_c : std_logic;                                         -- polaridad del reloj
  signal CPHA_c : std_logic;                                         -- fase del reloj
	
	signal spi_clk_count_s   : natural range 0 to (2*SPI_CLK_PRE)-1;
	signal spi_clk_s         : std_logic;
	signal spi_clk_edges_s   : natural range 0 to 2*SPI_DATA_SIZE;
	signal leading_edge_s    : std_logic;                              -- indica pasaje de sck desde idle a estado activo
	signal trailing_edge_s   : std_logic;                              -- indica pasaje de sck desde estado activo a idle
	signal tx_dv_s           : std_logic;
	signal tx_data_s         : std_logic_vector(SPI_DATA_SIZE-1 downto 0);
	signal tx_rdy_s          : std_logic;
	signal rx_data_s         : std_logic_vector(SPI_DATA_SIZE-1 downto 0);
	
	constant HIGH_INDEX      : natural := SPI_DATA_SIZE - 1;
	constant LOW_INDEX       : natural := 0;
	
	signal tx_bit_count_s    : natural range 0 to HIGH_INDEX;
	signal rx_bit_count_s    : natural range 0 to HIGH_INDEX;
	
begin
	-- Parte descriptiva
	CPOL_c <= '1' when (SPI_MODE = 2) or (SPI_MODE = 3) else '0';
	CPHA_c <= '1' when (SPI_MODE = 1) or (SPI_MODE = 3) else '0';
	
	-- Funcion:  Realiza la division del reloj clk_i de entrada 
	--           y genera los flancos que se usaran para la comunicacion
	edge_indicator : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                             -- mientras se mantenga en estado reset
	   tx_rdy_s        <= '1';
	   spi_clk_edges_s <=  0;
	   leading_edge_s  <= '0';
	   trailing_edge_s <= '0';
	   spi_clk_s       <= CPOL_c;                    -- estado de arranque por defecto del reloj en reposo
	   spi_clk_count_s <=  0;
	 
	 elsif rising_edge(clk_i) then                   -- sino esta en reset, espera flanco ascendente de clk_i
	   
	   leading_edge_s  <= '0';                       -- limpia valores por defecto
	   trailing_edge_s <= '0';                       -- limpia valores por defecto
	   
	   if tx_dv_s = '1' and tx_rdy_s = '1' then      -- cuando llega el pulso de dato válido,  
	     tx_rdy_s <= '0';                            -- el modulo se declara ocupado
	     spi_clk_edges_s <= 2*SPI_DATA_SIZE;         -- y programa 2*SPI_DATA_SIZE flancos de sck
	     
	   elsif spi_clk_edges_s > 0 then                -- mientras haya flancos pendientes,
	     tx_rdy_s <= '0';                            -- estamos en medio de la transmision, no acepta otro byte aun
	     
	     if spi_clk_count_s = (2*SPI_CLK_PRE)-1 then -- complete un periodo de spi_clk
	       spi_clk_edges_s <= spi_clk_edges_s - 1;   -- decremento numero de flancos restantes
	       trailing_edge_s <= '1';                   -- indico transicion de estado de sck activo a idle
	       spi_clk_count_s <= 0;                     -- reinicio contador del prescaler
	       spi_clk_s       <= not spi_clk_s;         -- toggleo sck
	     
	     elsif spi_clk_count_s = SPI_CLK_PRE-1 then  -- complete medio periodo de spi_clk
	       spi_clk_edges_s <= spi_clk_edges_s - 1;   -- decremento numero de flancos restantes
	       leading_edge_s  <= '1';                   -- indico transicion de estado de sck idle a activo
	       spi_clk_count_s <= spi_clk_count_s + 1;   -- incremento el contador de ciclos
	       spi_clk_s       <= not spi_clk_s;         -- toggleo sck
	     
	     else
	       spi_clk_count_s <= spi_clk_count_s + 1;   -- sino, incremento el contador de ciclos
	       
	     end if;
	   else
	     tx_rdy_s <= '1';                            -- el modulo vuelve a estar libre
	   end if;
	 end if;
	end process edge_indicator;
	
	-- Funcion:  Latch del dato de entrada y pipeline de la señal de "dato válido".
  --           Asegura que el byte quede estable durante toda la transferencia
  --           por mas que la entrada cambie y genera un pulso alineado (retardado 
  --           1 clk) para la lógica MOSI/MISO.
	data_latch : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                             -- mientras se mantenga en estado reset
	   tx_data_s <= (others => '0');                 -- limpia el buffer local de TX (dato estable interno)
	   tx_dv_s <= '0';                               -- borra el pulso de "dato válido" interno
	 elsif rising_edge(clk_i) then                   -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_dv_i = '1' and tx_rdy_s = '1' then      -- cuando la entidad superior afirma un dato valido
	     tx_dv_s   <= tx_dv_i;                       -- registra tx_dv_i: genera un pulso 1 clk más tarde
	     tx_data_s <= tx_data_i;                     -- crea una copia local del dato a transmitir
	   else
	     tx_dv_s   <= '0';
	   end if;
	 end if;
	end process data_latch;
	
	-- Funcion:  Genera la salida MOSI bit a bit
  --           Compatible con CPHA=0 y CPHA=1 usando los strobes de flanco.
	mosi_transfer : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                             -- mientras se mantenga en estado reset
	   spi_mosi_o     <= '0';
	   if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then
	     tx_bit_count_s <= HIGH_INDEX;
     else
       tx_bit_count_s <= LOW_INDEX;
     end if;
	   
	 elsif rising_edge(clk_i) then                   -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_rdy_s = '1' then              
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then    -- valor de precarga segun SPI_FIRST_BIT
	       tx_bit_count_s <= HIGH_INDEX;
       else
         tx_bit_count_s <= LOW_INDEX;
       end if;
	   
	     if tx_dv_s = '1' and CPHA_c = '0' then      -- precarga en el mismo ciclo
	       spi_mosi_o <= tx_data_s(tx_bit_count_s);
	     
	       if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then
	         if tx_bit_count_s > 0 then
	           tx_bit_count_s <= tx_bit_count_s-1;
	         end if;
         else
           if tx_bit_count_s < HIGH_INDEX then
             tx_bit_count_s <= tx_bit_count_s+1;
           end if;
         end if;
       else
         spi_mosi_o <= '0';                         -- sólo cuando esta idle y no acepto nada ese ciclo
       end if;
	   elsif (leading_edge_s = '1' and CPHA_c = '1') or (trailing_edge_s = '1' and CPHA_c = '0') then
	     spi_mosi_o <= tx_data_s(tx_bit_count_s);
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then
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
  --           Emite un pulso rx_dv_0 por 1 clk cuando el byte está listo.
	miso_capture : process(clk_i, rst_i)
	variable rx_data_v : std_logic_vector(SPI_DATA_SIZE-1 downto 0);
	begin
	 if rst_i = '0' then                             -- mientras se mantenga en estado reset
	   rx_data_s       <= (others => '0');
	   rx_data_o       <= (others => '0');
	   rx_dv_o         <= '0';
	   if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then
	     rx_bit_count_s <= HIGH_INDEX;
     else
       rx_bit_count_s <= LOW_INDEX;
     end if;
	   
	 elsif rising_edge(clk_i) then                   -- sino esta en reset, espera flanco ascendente de clk_i
	   rx_dv_o <= '0';
	   if tx_rdy_s = '1' then
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then    -- valor de precarga segun SPI_FIRST_BIT
	       rx_bit_count_s <= HIGH_INDEX;
       else
         rx_bit_count_s <= LOW_INDEX;
       end if;
	     
	   elsif (leading_edge_s = '1' and CPHA_c = '0') or (trailing_edge_s = '1' and CPHA_c = '1') then
	     rx_data_v := rx_data_s;
	     rx_data_v(rx_bit_count_s) := spi_miso_i;
	     rx_data_s(rx_bit_count_s) <= spi_miso_i;
	     
	     if SPI_FIRST_BIT = SPI_FIRSTBIT_MSB then
	       if rx_bit_count_s = 0 then
	         rx_data_o <= rx_data_v;
	         rx_dv_o <= '1';
	       else 
	         rx_bit_count_s <= rx_bit_count_s - 1;
	       end if;
	     else
	       if rx_bit_count_s = HIGH_INDEX then
	         rx_data_o <= rx_data_v;
	         rx_dv_o <= '1';
	       else
	         rx_bit_count_s <= rx_bit_count_s + 1;
	       end if;
	     end if;
	   end if;
	 end if;
	end process miso_capture;
	
	-- Funcion: anade un retardo de reloj para alinear senales
	clk_delay : process(clk_i, rst_i)
	begin
	  if rst_i = '0' then                             -- mientras se mantenga en estado reset
	    spi_clk_o <= CPOL_c;                          -- en reset, deja el SCK externo en su nivel idle (CPOL)
	  elsif rising_edge(clk_i) then                   -- sino esta en reset,
	    spi_clk_o <= spi_clk_s;                       -- sincroniza el reloj de salida con el generado
	  end if;
	end process clk_delay;
	
	-- Funcion: habilita/deshabilita el pin chip select
	cs_ctrl : process(clk_i, rst_i)
  begin
    if rst_i = '0' then
      spi_cs_o <= '1';
    elsif rising_edge(clk_i) then
      if (tx_dv_s = '1') and (tx_rdy_s = '1') then
        spi_cs_o <= '0';                            -- habilito CS al aceptar el dato
      elsif (tx_rdy_s = '1') then                   -- listo nuevamente (fin de ráfaga)
        spi_cs_o <= '1';                            -- deshabilito CS
      end if;
    end if;
  end process cs_ctrl;
	
	-- Actualiza estado de salida ready
	tx_rdy_o <= tx_rdy_s;
	
end architecture spi_master_arq;