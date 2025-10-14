-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_core is
  generic(
    DATA_SIZE     : positive;
    MODE          : natural;
    FIRST_BIT     : natural;
    CLOCK_RATE_HZ : positive;
    SCK_TARGET_HZ : positive 
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
end entity spi_core;

-- Cuerpo de arquitectura
architecture spi_core_arq of spi_core is
	-- Parte declarativa	
	
	-- Senales de SCK
	signal spi_clk_s         : std_logic;                                  -- sck interno
	signal leading_edge_s    : std_logic;                                  -- flanco de sck desde idle a estado activo segun SPI_MODE seleccionado
	signal trailing_edge_s   : std_logic;                                  -- flanco de sck desde estado activo a idle segun SPI_MODE seleccionado
	
	-- Control de transmision
	signal tx_rdy_s          : std_logic;                                  -- senal local para el manejo del ready y actualizarlo en el mismo ciclo al finalizar la transferencia
		
begin
	-- Parte descriptiva
	
	clk_gen_inst : entity work.clk_gen
	   generic map(
	      DATA_SIZE     => DATA_SIZE,
	      MODE          => MODE,
	      CLOCK_RATE_HZ => CLOCK_RATE_HZ,
        SCK_TARGET_HZ => SCK_TARGET_HZ
	   )
	   
	   port map (
	      -- Senales de control
	      rst_i           => rst_i,
        clk_i           => clk_i,
        
        -- Senales MOSI
        tx_dv_i         => tx_dv_i,
        
        -- Senales de SCK
        spi_clk_o       => spi_clk_o,
        leading_edge_o  => leading_edge_s,
        trailing_edge_o => trailing_edge_s,
        tx_rdy_o        => tx_rdy_s
      );
      
	mosi_transfer_inst : entity work.mosi_transfer
	   generic map (
	      DATA_SIZE     => DATA_SIZE,
	      MODE          => MODE,
        FIRST_BIT     => FIRST_BIT
	   )
	   
     port map (
        -- Senales de control
	      rst_i           => rst_i,
        clk_i           => clk_i,
    
        -- Senales MOSI
        tx_data_i       => tx_data_i,
        tx_dv_i         => tx_dv_i,
        tx_rdy_i        => tx_rdy_s,
        
        -- Senales de SCK
        leading_edge_i  => leading_edge_s,
        trailing_edge_i => trailing_edge_s,
    
        -- Interfaz SPI
        spi_mosi_o      => spi_mosi_o
     );
     
	miso_capture_inst : entity work.miso_capture
	   generic map (
	      DATA_SIZE     => DATA_SIZE,
	      MODE          => MODE,
        FIRST_BIT     => FIRST_BIT
	   )
	   
     port map (
        -- Senales de control
	      rst_i           => rst_i,
        clk_i           => clk_i,
    
        -- Senales MOSI
        tx_rdy_i        => tx_rdy_s,
        
        -- Senales MISO
        rx_data_o       => rx_data_o,
        rx_dv_o         => rx_dv_o,
        
        -- Senales de SCK
        leading_edge_i  => leading_edge_s,
        trailing_edge_i => trailing_edge_s,
    
        -- Interfaz SPI
        spi_miso_i      => spi_miso_i
     );
     
  cs_ctrl_inst : entity work.cs_ctrl
      port map (
        -- Senales MOSI
        tx_rdy_i        => tx_rdy_s,
        
        -- Interfaz SPI
        spi_cs_o        => spi_cs_o
      );
     
  -- Se actualiza puerto de salida
  tx_rdy_o  <= tx_rdy_s;
	
end architecture spi_core_arq;