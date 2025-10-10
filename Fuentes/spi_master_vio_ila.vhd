-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_master_vio_ila is
  port(
    clk_i     : in std_logic;     -- lo unico que entra a la FPGA es el reloj
  );   
end entity spi_master;

architecture spi_master_vio_ila_arq of spi_master_vio_ila is
  
  signal probe_rst  : std_logic_vector(0 downto 0);
  
  signal tx_data_i  : std_logic_vector(SPI_DATASIZE_8BIT-1 downto 0);
  signal tx_dv_i    : std_logic_vector(0 downto 0);
  signal tx_rdy_o   : std_logic_vector(0 downto 0);
  
  signal rx_data_o  : std_logic_vector(SPI_DATASIZE_8BIT-1 downto 0);
  signal rx_dv_o    : std_logic_vector(0 downto 0);
  
  signal spi_clk_o  : std_logic_vector(0 downto 0);
  signal spi_mosi_o : std_logic_vector(0 downto 0);
  signal spi_miso_i : std_logic_vector(0 downto 0);
  signal spi_cs_o   : std_logic_vector(0 downto 0);
    
  begin
  spi_master_inst : spi_master
    port map(
      rst_i       => probe_rst,       -- salida del vio -> 1 bit
      clk_i       => clk_i,           -- reloj general
    
      tx_data_i   => probe_data_i,    -- salida del vio -> 8 bits (dato a transmitir)
      tx_dv_i     => probe_dv_i,      -- salida del vio -> 1 bit (pulso dato valido para transmitir)
      tx_rdy_o    => probe_rdy_o,     -- entrada del vio -> 1 bit (estado modulo listo)
   
      rx_data_o   => probe_rx_data_o, -- entrada del vio -> 8 bits (dato recibido)
      rx_dv_o     => probe_rx_dv_o,   -- entrada del vio -> 1 bit (pulso dato valido recibido)
    
      spi_clk_o   => probe_clk,       -- entrada del ila
      spi_mosi_o  => probe_mosi_o,    -- entrada del ila
      spi_miso_i  => probe_miso_i,    -- salida del vio -> std_logic
      spi_cs_o    => probe_cs_o       -- entrada del ila
    );
end architecture spi_master_vio_ila_arq;