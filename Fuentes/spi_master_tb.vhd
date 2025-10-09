-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_master_tb is  
end entity spi_master_tb;

-- Cuerpo de arquitectura
architecture spi_master_tb_arq of spi_master_tb is
	-- Parte declarativa
	constant CLK_PERIOD : time := 10 ns; -- 100 MHz
	constant MISO_BYTE : std_logic_vector(SPI_DATASIZE_8BIT-1 downto 0) := x"55";
	
	signal rst_i       : std_logic := '0';
  signal clk_i       : std_logic := '0';
  
  signal tx_data_i   : std_logic_vector(SPI_DATASIZE_8BIT-1 downto 0) := (others => '0');
  signal tx_dv_i     : std_logic := '0';
  signal tx_rdy_o    : std_logic;
  
  signal rx_data_o   : std_logic_vector(SPI_DATASIZE_8BIT-1 downto 0);
  signal rx_dv_o     : std_logic;
  
  signal spi_clk_o   : std_logic;
  signal spi_mosi_o  : std_logic;
  signal spi_miso_i  : std_logic := '0';
  signal spi_cs_o    : std_logic;
  
  signal spi_miso_index : integer range -1 to SPI_DATASIZE_8BIT-1 := SPI_DATASIZE_8BIT-1;
	
begin
	-- Parte descriptiva
  spi_master_inst : entity work.spi_master
  generic map(
      SPI_DATA_SIZE => SPI_DATASIZE_8BIT,
      SPI_MODE      => SPI_MODE_0,
      SPI_CLK_PRE   => 4,                 -- sck = 100MHz/(2*4)=12.5 MHz
      SPI_FIRST_BIT => SPI_FIRSTBIT_MSB
  )
  
  port map(
      rst_i       => rst_i,
      clk_i       => clk_i,
      
      tx_data_i   => tx_data_i,
      tx_dv_i     => tx_dv_i,
      tx_rdy_o    => tx_rdy_o,
      
      rx_data_o   => rx_data_o,
      rx_dv_o     => rx_dv_o,
      
      spi_clk_o   => spi_clk_o,
      spi_mosi_o  => spi_mosi_o,
      spi_miso_i  => spi_miso_i,
      spi_cs_o    => spi_cs_o
  );
  
  -- Generador del reloj
  -- Funcion: genera el reloj que comanda el sistema
  clk_gen: process
  begin
    clk_i <= '0'; wait for CLK_PERIOD/2;
    clk_i <= '1'; wait for CLK_PERIOD/2;
  end process clk_gen;
  
  -- Controlador de reset
  reset_ctrl: process
  begin
    rst_i <= '0'; wait for 100 ns;                    -- mantiene el reset durante los primeros 100 ns
    rst_i <= '1'; wait;
  end process reset_ctrl;
  
  -- Generador de mensaje a transmitir
  data_transmit: process
  begin
    wait until rst_i = '1';                           -- espera mientras se mantiene el reset
    
    wait until rising_edge(clk_i) and tx_rdy_o = '1'; -- espera el tx_rdy_o

    tx_data_i <= x"A5";     -- 10100101 (MSB primero)
    tx_dv_i   <= '1';       -- pulso de 1 ciclo
    wait until rising_edge(clk_i);
    tx_dv_i   <= '0';

    -- deja correr para ver los 8 bits en mosi y el sck
    wait for 800 ns;
    wait;
  end process data_transmit;
  
  data_receive : process(spi_cs_o, spi_clk_o)
  begin
    if spi_cs_o = '1' then
      spi_miso_i <= '0';
      spi_miso_index <= SPI_DATASIZE_8BIT-1;
    else
      if spi_miso_index = SPI_DATASIZE_8BIT-1 then
        spi_miso_i <= MISO_BYTE(spi_miso_index);
        spi_miso_index <= spi_miso_index - 1;
      end if;
      
      if falling_edge(spi_clk_o) then
        if spi_miso_index > (-1) then
          spi_miso_i <= MISO_BYTE(spi_miso_index);
          spi_miso_index <= spi_miso_index - 1;
        else
          spi_miso_i <= '0';
        end if;
      end if;
    end if;
  end process data_receive;
	
end architecture spi_master_tb_arq;