-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_top_vio_ila is
  port(
    clk_i     : in std_logic_vector(0 downto 0)  -- lo unico que entra a la FPGA es el reloj
  );   
  
end entity spi_top_vio_ila;

architecture spi_top_vio_ila_arq of spi_top_vio_ila is
  
  component spi_top
  port(
    rst_i       : in std_logic;
    clk_i       : in std_logic;
    
    tx_data_i   : in  std_logic_vector(7 downto 0);
    tx_dv_i     : in  std_logic;
    tx_rdy_o    : out std_logic;
    
    rx_data_o   : out std_logic_vector(7 downto 0);
    rx_dv_o     : out std_logic;
    
    spi_clk_o   : out std_logic;
    spi_mosi_o  : out std_logic;
    spi_miso_i  : in  std_logic;
    spi_cs_o    : out std_logic
  );
  end component;
  
  component vio
    port (
        clk        : in  std_logic_vector(0 downto 0);
        probe_in0  : in  std_logic_vector(0 downto 0);
        probe_in1  : in  std_logic_vector(7 downto 0);
        probe_in2  : in  std_logic_vector(0 downto 0);
        probe_out0 : out std_logic_vector(0 downto 0);
        probe_out1 : out std_logic_vector(7 downto 0);
        probe_out2 : out std_logic_vector(0 downto 0);
        probe_out3 : out std_logic_vector(0 downto 0)
  );
  end component;
  
  component ila
    port (
        clk    : in std_logic_vector(0 downto 0);
        probe0 : in std_logic_vector(0 downto 0); 
        probe1 : in std_logic_vector(0 downto 0);
        probe2 : in std_logic_vector(0 downto 0)
  );
  end component;
  
  signal probe_rst        : std_logic_vector(0 downto 0);
  
  signal probe_tx_data_i  : std_logic_vector(7 downto 0);
  signal probe_tx_dv_i    : std_logic_vector(0 downto 0);
  signal probe_tx_rdy_o   : std_logic_vector(0 downto 0);
  
  signal probe_rx_data_o  : std_logic_vector(7 downto 0);
  signal probe_rx_dv_o    : std_logic_vector(0 downto 0);
  
  signal probe_spi_clk_o  : std_logic_vector(0 downto 0);
  signal probe_spi_mosi_o : std_logic_vector(0 downto 0);
  signal probe_spi_miso_i : std_logic_vector(0 downto 0);
  signal probe_spi_cs_o   : std_logic_vector(0 downto 0);
    
begin
  spi_top_inst : spi_top
    port map(
      rst_i       => probe_rst(0),           -- salida del vio -> 1 bit
      clk_i       => clk_i(0),               -- reloj general
    
      tx_data_i   => probe_tx_data_i,        -- salida del vio -> 8 bits (dato a transmitir)
      tx_dv_i     => probe_tx_dv_i(0),       -- salida del vio -> 1 bit (pulso dato valido para transmitir)
      tx_rdy_o    => probe_tx_rdy_o(0),      -- entrada del vio -> 1 bit (estado modulo listo)
   
      rx_data_o   => probe_rx_data_o,        -- entrada del vio -> 8 bits (dato recibido)
      rx_dv_o     => probe_rx_dv_o(0),       -- entrada del vio -> 1 bit (pulso dato valido recibido)
    
      spi_clk_o   => probe_spi_clk_o(0),     -- entrada del ila
      spi_mosi_o  => probe_spi_mosi_o(0),    -- entrada del ila
      spi_miso_i  => probe_spi_miso_i(0),    -- salida del vio -> std_logic
      spi_cs_o    => probe_spi_cs_o(0)       -- entrada del ila
    );
    
    vio_inst : vio
      port map (
        clk => clk_i,
        probe_in0 => probe_tx_rdy_o,
        probe_in1 => probe_rx_data_o,
        probe_in2 => probe_rx_dv_o,
        probe_out0 => probe_rst,
        probe_out1 => probe_tx_data_i,
        probe_out2 => probe_tx_dv_i,
        probe_out3 => probe_spi_miso_i
      );
      
    ila_inst : ila
      port map (
        clk => clk_i,
        probe0 => probe_spi_clk_o, 
        probe1 => probe_spi_mosi_o,
        probe2 => probe_spi_cs_o
      );
end architecture spi_top_vio_ila_arq;