-- Bibliotecas
library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.spi_pkg.all;

-- Declaracion de entidad
entity cs_ctrl is
  port(
    -- Senales MOSI
    tx_rdy_i  : in  std_logic;                                           -- listo para aceptar un nuevo dato
    
    -- Interfaz SPI
    spi_cs_o    : out std_logic                                          -- linea CS (Chip Select)
  );   
end entity cs_ctrl;

-- Cuerpo de arquitectura
architecture cs_ctrl_arq of cs_ctrl is
	-- Parte declarativa
	
begin
	-- Parte descriptiva
	
	spi_cs_o <= '0' when (tx_rdy_i = '0') else '1';                        -- Habilita/deshabilita el pin chip select
	
end architecture cs_ctrl_arq;