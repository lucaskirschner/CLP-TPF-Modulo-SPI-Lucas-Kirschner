-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_clk_gen_tb is
end entity spi_clk_gen_tb;

-- Cuerpo de arquitectura
architecture spi_clk_gen_tb_arq of spi_clk_gen_tb is
	-- Parte declarativa
	signal rst_i   : std_logic := '0';
	signal clk_i   : std_logic := '0';
	
	signal cpol_i  : std_logic := '0';
	signal tx_dv_i : std_logic := '0';
	
  signal spi_clk_o       : std_logic;
  signal leading_edge_o  : std_logic;
  signal trailing_edge_o : std_logic;
  signal tx_rdy_o        : std_logic;

begin
  rst_i   <= '1' after 30 ns;
  tx_dv_i <= '1' after 40 ns;
 	clk_i <= not clk_i after 4 ns;
  
	spi_clk_gen_inst : entity work.spi_clk_gen
	generic map(
    DATA_SIZE     => DATASIZE_8BIT,
    MODE          => MODE_0,
    CLOCK_RATE_HZ => 125000000,
    SCK_TARGET_HZ => 12500000
  )
    
  port map(
    -- Senales de control
    rst_i             => rst_i,
    clk_i             => clk_i,
    
    tx_dv_i           => tx_dv_i,
    
   	spi_clk_o         => spi_clk_o,
	  leading_edge_o    => leading_edge_o,
	  trailing_edge_o   => trailing_edge_o,
	  tx_rdy_o          => tx_rdy_o
  );   			
	-- Parte descriptiva
end architecture spi_clk_gen_tb_arq;