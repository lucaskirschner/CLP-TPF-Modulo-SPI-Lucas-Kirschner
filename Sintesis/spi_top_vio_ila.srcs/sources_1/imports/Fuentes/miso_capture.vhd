-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity miso_capture is
  generic(
    DATA_SIZE : natural;
    MODE      : natural;
    FIRST_BIT : natural
  );
    
  port(
    -- Senales de control
    rst_i     : in std_logic;                                            -- reset activo en bajo
    clk_i     : in std_logic;                                            -- reloj del sistema
    
    -- Senales MOSI
    tx_rdy_i  : in std_logic;                                            -- listo para aceptar un nuevo dato
   
    -- Senales MISO
    rx_data_o : out std_logic_vector(DATA_SIZE-1 downto 0);              -- dato de salida recibido por spi_miso_i
    rx_dv_o   : out std_logic;                                           -- pulso: dato de entrada listo en rx_data_o
    
    -- Senales de SCK
 	  leading_edge_i    : in std_logic;  -- flanco de sck desde idle a estado activo segun SPI_MODE seleccionado
	  trailing_edge_i   : in std_logic;  -- flanco de sck desde estado activo a idle segun SPI_MODE seleccionado 
    
    -- Interfaz SPI
    spi_miso_i  : in  std_logic                                          -- linea MISO (Master In Slave Out)
  );   
end entity miso_capture;

-- Cuerpo de arquitectura
architecture miso_capture_arq of miso_capture is
	-- Parte declarativa
	
	-- Constantes
	constant HIGH_INDEX      : natural := DATA_SIZE - 1;                   -- indice superior para cuenta ascendente en modo MSB FIRST BIT
	constant LOW_INDEX       : natural := 0;                               -- indice inferior para cuenta descendente en modo LSB FIRST BIT
	
	-- Derivacion de modo
  signal cpha_c : std_logic;                                             -- fase de sck para muestreo/actualizacion
		
	-- Control de recepcion
	signal rx_data_s         : std_logic_vector(DATA_SIZE-1 downto 0);     -- vector local para armar el vector de datos de entrada
	signal rx_bit_count_s    : natural range 0 to HIGH_INDEX;              -- contador de bits recibidos
	
begin
	-- Parte descriptiva
	cpha_c <= '1' when (MODE = 1) or (MODE = 3) else '0';            -- determina fase del reloj segun SPI_MODE seleccionado

	miso_capture_proc : process(clk_i, rst_i)
	variable rx_data_v : std_logic_vector(DATA_SIZE-1 downto 0);     -- vector variable de dato de entrada
	begin
	 if rst_i = '0' then                                             -- mientras se mantenga en estado reset
	   rx_data_s       <= (others => '0');
	   rx_data_o       <= (others => '0');
	   rx_dv_o         <= '0';
	   
	   if FIRST_BIT = FIRSTBIT_MSB then                              -- si va primero el MSB
	     rx_bit_count_s <= HIGH_INDEX;                               -- indice = extremo superior
     else                                                          -- si va primero el LSB
       rx_bit_count_s <= LOW_INDEX;                                -- indice = extremo inferior
     end if; 
	   
	 elsif rising_edge(clk_i) then                                   -- sino esta en reset, espera flanco ascendente de clk_i
	   rx_dv_o <= '0';
	   if tx_rdy_i = '1' then
	     if FIRST_BIT = FIRSTBIT_MSB then                            -- asegura precarga de indice
	       rx_bit_count_s <= HIGH_INDEX;
       else
         rx_bit_count_s <= LOW_INDEX;
       end if;
	     
	   elsif (leading_edge_i = '1' and cpha_c = '0')                 -- en CPHA = 0, se lee dato en leading y actualiza en trailing
	     or (trailing_edge_i = '1' and cpha_c = '1') then            -- en CPHA = 1, se lee dato en trailing y se actualiza en leading
	     
	     rx_data_v := rx_data_s;                                     -- tomo el ultimo vector de datos. rx_data_s usada como shift register
	     rx_data_v(rx_bit_count_s) := spi_miso_i;                    -- actualizo con el ultimo bit recibido
	     rx_data_s(rx_bit_count_s) <= spi_miso_i;
	     
	     if FIRST_BIT = FIRSTBIT_MSB then                            -- segun el modo de transferencia de bits
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
	end process miso_capture_proc;
	
end architecture miso_capture_arq;