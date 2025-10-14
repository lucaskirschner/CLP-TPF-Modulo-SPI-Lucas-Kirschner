-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity mosi_transfer is
  generic(
    DATA_SIZE     : natural;
    MODE          : natural;
    FIRST_BIT     : natural
  );
    
  port(
    -- Senales de control
    rst_i     : in std_logic;                                            -- reset activo en bajo
    clk_i     : in std_logic;                                            -- reloj del sistema
    
    -- Senales MOSI
    tx_data_i : in  std_logic_vector(DATA_SIZE-1 downto 0);             -- dato de entrada a transmitir por spi_mosi_o
    tx_dv_i   : in  std_logic;                                           -- pulso: indica dato valido en tx_data_i
    tx_rdy_i  : in  std_logic;
    
    -- Senales de SCK
 	  leading_edge_i    : in std_logic;  -- flanco de sck desde idle a estado activo segun SPI_MODE seleccionado
	  trailing_edge_i   : in std_logic;  -- flanco de sck desde estado activo a idle segun SPI_MODE seleccionado   
	   
    -- Interfaz SPI
    spi_mosi_o  : out std_logic                                          -- linea MOSI (Master Out Slave In)
  );   
end entity mosi_transfer;

-- Cuerpo de arquitectura
architecture mosi_transfer_arq of mosi_transfer is
	-- Parte declarativa
	
	-- Constantes
	constant HIGH_INDEX      : natural := DATA_SIZE - 1;                   -- indice superior para cuenta ascendente en modo MSB FIRST BIT
	constant LOW_INDEX       : natural := 0;                               -- indice inferior para cuenta descendente en modo LSB FIRST BIT
	
	-- Derivacion de modo
  signal cpha_c : std_logic;                                             -- fase de sck para muestreo/actualizacion
	
	-- Control de transmision
	signal tx_data_s         : std_logic_vector(DATA_SIZE-1 downto 0);     -- vector local para 'congelar' el dato a transmitir
	signal tx_dv_s           : std_logic;                                  -- senal local para retrasar un ciclo el pulso dato valido de entrada
	signal tx_bit_count_s    : natural range 0 to HIGH_INDEX;              -- contador de bits transmitidos
	signal tx_mosi_s         : std_logic;                                  -- registro interno para actualización inmediata de spi_mosi_o
	
begin
	-- Parte descriptiva
	cpha_c <= '1' when (MODE = MODE_1) or (MODE = MODE_3) else '0';  -- determina fase del reloj segun SPI_MODE seleccionado
	
	data_latch_proc : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   tx_data_s <= (others => '0');                     -- limpia el buffer local de tx (dato estable interno)
	   tx_dv_s <= '0';                                   -- borra el pulso de "dato valido" interno
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_dv_i = '1' and tx_rdy_i = '1' then          -- cuando la entidad superior afirma un dato valido
	     tx_dv_s   <= tx_dv_i;                           -- registra tx_dv_i: genera un pulso 1 clk más tarde
	     tx_data_s <= tx_data_i;                         -- crea una copia local del dato a transmitir
	   else                                              -- sino
	     tx_dv_s   <= '0';                               -- indica que no hay datos de entrada validos
	   end if;
	 end if;
	end process data_latch_proc;
	
	mosi_transfer_proc : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   tx_mosi_s     <= '0';                             -- la salida permanece inactiva
	   
	   if FIRST_BIT = FIRSTBIT_MSB then                  -- si va primero el MSB
	     tx_bit_count_s <= HIGH_INDEX;                   -- indice = extremo superior
     else                                              -- si va primero el LSB
       tx_bit_count_s <= LOW_INDEX;                    -- indice = extremo inferior
     end if;                      
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_rdy_i = '1' then                            -- si hay un dato valido de entrada y es el primer ciclo
	     
	     if FIRST_BIT = FIRSTBIT_MSB then                -- asegura precarga de indice
	       tx_bit_count_s <= HIGH_INDEX;
       else
         tx_bit_count_s <= LOW_INDEX;
       end if;
	   
	     if tx_dv_s = '1' and cpha_c = '0' then          -- en el modo CPHA = 0 el esclavo muestrea el primer bit en el primer flanco,
	       tx_mosi_s <= tx_data_s(tx_bit_count_s);       -- por lo que debe arrancar listo
	     
	       if FIRST_BIT = FIRSTBIT_MSB then              -- decrementa o incrementa indice segun modo
	         if tx_bit_count_s > 0 then
	           tx_bit_count_s <= tx_bit_count_s-1;
	         end if;
         else
           if tx_bit_count_s < HIGH_INDEX then
             tx_bit_count_s <= tx_bit_count_s+1;
           end if;
         end if;
         
       elsif tx_rdy_i = '1' then                        -- si no llego un nuenvo dato pero esta ready
         tx_mosi_s <= '0';                              -- MOSI permanece en estado idle
       end if;
       
	   elsif (leading_edge_i = '1' and cpha_c = '1')      -- en CPHA = 1, se lee dato en trailing y se actualiza en leading
	      or (trailing_edge_i = '1' and cpha_c = '0') then-- en CPHA = 0, se lee dato en leading y actualiza en trailing
	     
	     tx_mosi_s <= tx_data_s(tx_bit_count_s);          -- actualiza el dato
	     
	     if FIRST_BIT = FIRSTBIT_MSB then                 -- decrementa o incrementa indice segun modo
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
	end process mosi_transfer_proc;
	
	-- Actualiza estado de salida mosi
	spi_mosi_o <= '0' when (tx_rdy_i = '1') else tx_mosi_s;
	
end architecture mosi_transfer_arq;