-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity clk_gen is
  generic(
    DATA_SIZE     : natural;
    MODE          : natural;
    CLOCK_RATE_HZ : positive;
    SCK_TARGET_HZ : positive
  );
    
  port(
    -- Senales de control
    rst_i             : in std_logic;   -- reset activo en bajo
    clk_i             : in std_logic;   -- reloj del sistema
    
    tx_dv_i           : in std_logic;   -- pulso: indica dato valido en tx_data_i -> inicia spi_clk
    
   	spi_clk_o         : out std_logic;  -- sck interno
	  leading_edge_o    : out std_logic;  -- flanco de sck desde idle a estado activo segun SPI_MODE seleccionado
	  trailing_edge_o   : out std_logic;  -- flanco de sck desde estado activo a idle segun SPI_MODE seleccionado
	  tx_rdy_o          : out std_logic
  );   
end entity clk_gen;

-- Cuerpo de arquitectura
architecture clk_gen_arq of clk_gen is
	-- Parte declarativa
	
	-- Constantes
  constant HALF_RATE   : natural := 2 * SCK_TARGET_HZ;
  constant SPI_CLK_PRE : natural := (CLOCK_RATE_HZ + HALF_RATE/2) / HALF_RATE;
  
  	-- Derivacion de modo
	signal cpol_c : std_logic;                                             -- polaridad de SCK (estado en modo idle)
	
	-- Generacion de SCK y flancos
	signal spi_clk_count_s   : natural range 0 to (2*SPI_CLK_PRE)-1;       -- cuenta numero de ciclos para division de scl_i
	signal spi_clk_s         : std_logic;                                  -- sck interno
	signal spi_clk_edges_s   : natural range 0 to 2*DATA_SIZE;             -- cuenta flancos restantes para finalizar la transmision/recepcion
	
	-- Control de transmision
	signal tx_rdy_s          : std_logic;                                  -- senal local para el manejo del ready y actualizarlo en el mismo ciclo al finalizar la transferencia
	signal tx_dv_s           : std_logic;                                  -- senal local para retrasar un ciclo el pulso dato valido de entrada
			
begin
	-- Parte descriptiva
	cpol_c <= '1' when (MODE = MODE_2) or (MODE = MODE_3) else '0';  -- determina polaridad del reloj segun SPI_MODE seleccionado
	
	data_latch_proc : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   tx_dv_s <= '0';                                   -- borra el pulso de "dato valido" interno
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   if tx_dv_i = '1' and tx_rdy_s = '1' then          -- cuando la entidad superior afirma un dato valido
	     tx_dv_s   <= tx_dv_i;                           -- registra tx_dv_i: genera un pulso 1 clk más tarde
	   else                                              -- sino
	     tx_dv_s   <= '0';                               -- indica que no hay datos de entrada validos
	   end if;
	 end if;
	end process data_latch_proc;
	
	clk_gen_proc : process(clk_i, rst_i)
	begin
	 if rst_i = '0' then                                 -- mientras se mantenga en estado reset
	   spi_clk_count_s <=  0;                            -- configuro el estado de arranque de sck
	   spi_clk_s       <= cpol_c;
	   spi_clk_edges_s <=  0;
	   leading_edge_o  <= '0';
	   trailing_edge_o <= '0';
	   tx_rdy_s        <= '1';                           -- asumo que se mantiene listo para recibir un nuevo dato
	   
	 elsif rising_edge(clk_i) then                       -- sino esta en reset, espera flanco ascendente de clk_i
	   leading_edge_o  <= '0';                           -- limpia valores por defecto
	   trailing_edge_o <= '0';                           -- limpia valores por defecto
	   
	   if tx_dv_s = '1' and tx_rdy_s = '1' then          -- cuando llega el pulso de dato válido y el modulo esta listo para recibirlo  
	     tx_rdy_s <= '0';                                -- el modulo se declara ocupado
	     spi_clk_edges_s <= 2*DATA_SIZE;                 -- y programa los flancos de sck necesarios para completar la transmision/recepcion
	     
	   elsif spi_clk_edges_s > 0 then                    -- mientras haya flancos pendientes programados
	     tx_rdy_s <= '0';                                -- el modulo se matiene ocupado
	     
	     if spi_clk_count_s = SPI_CLK_PRE-1 then         -- si complete medio periodo de spi_clk
	       spi_clk_count_s <= spi_clk_count_s + 1;       -- incremento el contador de ciclos
	       spi_clk_edges_s <= spi_clk_edges_s - 1;       -- decremento numero de flancos restantes
	       leading_edge_o  <= '1';                       -- indico transicion de estado de sck: idle => activo
	       spi_clk_s       <= not spi_clk_s;             -- toggleo sck interno
	       
	     elsif spi_clk_count_s = (2*SPI_CLK_PRE)-1 then  -- si complete un periodo de spi_clk
	       spi_clk_count_s <= 0;                         -- reinicio contador de ciclos
	       spi_clk_edges_s <= spi_clk_edges_s - 1;       -- decremento numero de flancos restantes
	       trailing_edge_o <= '1';                       -- indico transicion de estado de sck: activo => idle
	       spi_clk_s       <= not spi_clk_s;             -- toggleo sck interno
	       
	     else                                            -- sino
	       spi_clk_count_s <= spi_clk_count_s + 1;       -- incremento el contador de ciclos
	       
	     end if;                                         -- si ya no hay flancos pendientes
	   else
	     tx_rdy_s <= '1';                                -- el modulo vuelve a estar libre
	     
	   end if;
	 end if;
	end process clk_gen_proc;
	
	clk_delay_proc : process(clk_i, rst_i)
	begin
	  if rst_i = '0' then                             -- mientras se mantenga en estado reset
	    spi_clk_o <= cpol_c;                          -- en reset, deja el SCK externo en su nivel idle (CPOL)
	  elsif rising_edge(clk_i) then                   -- sino esta en reset,
	    spi_clk_o <= spi_clk_s;                       -- sincroniza el reloj de salida con el generado
	  end if;
	end process clk_delay_proc;
	
	-- Actualiza variables en los puertos
	tx_rdy_o <= tx_rdy_s;
	
	
end architecture clk_gen_arq;