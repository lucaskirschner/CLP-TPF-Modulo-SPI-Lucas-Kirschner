package SPI_pkg is
  -- Tamaño de palabra
  constant DATASIZE_8BIT          : natural  := 8;
  constant DATASIZE_16BIT         : natural  := 16;
  
  -- Modo
  constant MODE_0                 : natural  := 0;
  constant MODE_1                 : natural  := 1;
  constant MODE_2                 : natural  := 2;
  constant MODE_3                 : natural  := 3;

  -- Orden de bits
  constant FIRSTBIT_LSB           : natural  := 0;
  constant FIRSTBIT_MSB           : natural  := 1;

end package SPI_pkg;
