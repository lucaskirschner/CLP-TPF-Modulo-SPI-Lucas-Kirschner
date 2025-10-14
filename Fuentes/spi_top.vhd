-------------------------------------------------------------------------------
-- Descripción:  SPI (Interfaz Periferica Serial) Maestro
--               Con capacidad para un unico Chip Select/Slave Select
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
-- Parámetros: 
--               MODE : Define el modo de operación SPI (0, 1, 2 o 3).
--
--               DATA_SIZE : Define la longitud de palabra de datos, 
--               pudiendo seleccionarse entre 8 o 16 bits.
--               
--               FIRST_BIT : Define si se trasnmite primero el bit más 
--               significativo (FIRSTBIT_MSB) el el menos significativo (FIRSTBIT_LSB)
--
--               CLOCK_RATE_HZ : Frecuencia de entrada clk_i según la FPGA
--
--               SCK_TARGET_HZ : Frecuencia objetivo para la comunicación SPI
--
--               CS : Este módulo controla automáticamente la señal CS, 
--               manteniéndola baja durante la transferencia y 
--               liberándola al finalizar la comunicación.
-------------------------------------------------------------------------------

-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_top is
  generic(
    DATA_SIZE     : positive  := DATASIZE_8BIT; -- largo de la trama
    MODE          : natural   := MODE_0;        -- modo SPI
    FIRST_BIT     : natural   := FIRSTBIT_MSB;  -- orden de transferencia
    CLOCK_RATE_HZ : positive  := 125e6;         -- clk_i => 125 MHz
    SCK_TARGET_HZ : positive  := 125e5          -- spi_clk_o => 12,5 Mbps
  );
    
  port(
    -- Senales de control
    rst_i     : in std_logic;                                            -- reset activo en bajo
    clk_i     : in std_logic;                                            -- reloj del sistema
    
    -- Senales MOSI
    tx_data_i : in  std_logic_vector(DATA_SIZE-1 downto 0);              -- dato de entrada a transmitir por spi_mosi_o
    tx_dv_i   : in  std_logic;                                           -- pulso: indica dato valido en tx_data_i
    tx_rdy_o  : out std_logic;                                           -- listo para aceptar un nuevo dato
   
    -- Senales MISO
    rx_data_o : out std_logic_vector(DATA_SIZE-1 downto 0);              -- dato de salida recibido por spi_miso_i
    rx_dv_o   : out std_logic;                                           -- pulso: dato de entrada listo en rx_data_o
    
    -- Interfaz SPI
    spi_clk_o   : out std_logic;                                         -- linea SCK
    spi_mosi_o  : out std_logic;                                         -- linea MOSI (Master Out Slave In)
    spi_miso_i  : in  std_logic;                                         -- linea MISO (Master In Slave Out)
    spi_cs_o    : out std_logic                                          -- linea CS (Chip Select)
  );   
end entity spi_top;

-- Cuerpo de arquitectura
architecture spi_top_arq of spi_top is
  -- Parte declarativa

begin
  -- Parte descriptiva
	
	spi_core_inst: entity work.spi_core
	generic map (
	  DATA_SIZE     => DATA_SIZE,
	  MODE          => MODE,
	  FIRST_BIT     => FIRST_BIT,
    CLOCK_RATE_HZ => CLOCK_RATE_HZ,
    SCK_TARGET_HZ => SCK_TARGET_HZ
    )
    
  port map (
    clk_i      => clk_i,
    rst_i      => rst_i,
    
    tx_data_i  => tx_data_i,
    tx_dv_i    => tx_dv_i,
    tx_rdy_o   => tx_rdy_o,
    
    rx_data_o  => rx_data_o,
    rx_dv_o    => rx_dv_o,
    
    spi_clk_o  => spi_clk_o,
    spi_mosi_o => spi_mosi_o,
    spi_miso_i => spi_miso_i,
    spi_cs_o   => spi_cs_o
    );
    
end architecture spi_top_arq;