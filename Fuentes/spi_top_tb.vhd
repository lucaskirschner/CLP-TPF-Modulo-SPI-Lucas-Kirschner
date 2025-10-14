-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity spi_top_tb is  
end entity spi_top_tb;

-- Cuerpo de arquitectura
architecture spi_top_tb_arq of spi_top_tb is
	-- Parte declarativa
	
	constant CLOCK_RATE_HZ : positive := 125000000;              -- 125 MHz
	constant CLK_PERIOD    : time     := 1 sec / CLOCK_RATE_HZ;  -- 8ns
	constant SCK_TARGET_HZ : positive := 12500000;               -- 12,5Mbps
	
	constant MISO_BYTE : std_logic_vector(DATASIZE_8BIT-1 downto 0) := x"55";
	
	signal rst_i       : std_logic := '0';
  signal clk_i       : std_logic := '0';
  
  signal tx_data_i   : std_logic_vector(DATASIZE_8BIT-1 downto 0) := (others => '0');
  signal tx_dv_i     : std_logic := '0';
  signal tx_rdy_o    : std_logic;
  
  signal rx_data_o   : std_logic_vector(DATASIZE_8BIT-1 downto 0);
  signal rx_dv_o     : std_logic;
  
  signal spi_clk_o   : std_logic;
  signal spi_mosi_o  : std_logic;
  signal spi_miso_i  : std_logic := '0';
  signal spi_cs_o    : std_logic;
  
  signal spi_miso_index : integer range -1 to DATASIZE_8BIT-1 := DATASIZE_8BIT-1;
	
begin
	-- Parte descriptiva
  spi_top_inst : entity work.spi_top
  generic map(
      DATA_SIZE     => DATASIZE_8BIT,
      MODE          => MODE_0,
      FIRST_BIT     => FIRSTBIT_MSB,
      CLOCK_RATE_HZ => CLOCK_RATE_HZ,
      SCK_TARGET_HZ => SCK_TARGET_HZ
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
    clk_i <= '0'; wait for CLK_PERIOD/2;             -- medio periodo inicial de clk_i
    clk_i <= '1'; wait for CLK_PERIOD/2;             -- medio periodo final de clk_i
  end process clk_gen;
  
  -- Controlador de reset
  reset_ctrl: process
  begin
    rst_i <= '0'; wait for 20 ns;                    -- mantiene el reset durante los primeros 20 ns
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
      spi_miso_index <= DATASIZE_8BIT-1;
    else
      if spi_miso_index = DATASIZE_8BIT-1 then
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
	
end architecture spi_top_tb_arq;