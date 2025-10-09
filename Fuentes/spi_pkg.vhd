package SPI_pkg is
  -- Tamaño de palabra
  constant SPI_DATASIZE_8BIT          : natural  := 8;
  constant SPI_DATASIZE_16BIT         : natural  := 16;
  
  -- Modo
  constant SPI_MODE_0                 : natural  := 0;
  constant SPI_MODE_1                 : natural  := 1;
  constant SPI_MODE_2                 : natural  := 2;
  constant SPI_MODE_3                 : natural  := 3;

  -- Polaridad y fase
  constant SPI_POLARITY_LOW           : natural  := 0;
  constant SPI_POLARITY_HIGH          : natural  := 1;

  constant SPI_PHASE_1EDGE            : natural  := 0;
  constant SPI_PHASE_2EDGE            : natural  := 1;

  -- Prescaler (factor)
  constant SPI_CLK_PRESCALER_125KBPS  : natural  := 500;

  -- Orden de bits
  constant SPI_FIRSTBIT_LSB           : natural  := 0;
  constant SPI_FIRSTBIT_MSB           : natural  := 1;

end package SPI_pkg;
