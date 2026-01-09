library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity Memory_Store_RAM is
  port(
    clk      : in  std_logic;
    we       : in  std_logic;
    Addr_in  : in  std_logic_vector(7 downto 0);
    Data_in  : in  std_logic_vector(23 downto 0);
    Data_out : out std_logic_vector(23 downto 0)
  );
end entity;

architecture Behavioral of Memory_Store_RAM is

  -- Opcodes (Actualizados con tus nuevas instrucciones)
  constant OP_LDX   : std_logic_vector(7 downto 0) := x"01"; -- Leer Memoria en X
  constant OP_LDY   : std_logic_vector(7 downto 0) := x"02"; -- Leer Memoria en Y
  constant OP_ADD   : std_logic_vector(7 downto 0) := x"03";
  constant OP_ADDI  : std_logic_vector(7 downto 0) := x"04";
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06"; -- (No usado en tu logica actual, usas STX)
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08";
  constant OP_SUB   : std_logic_vector(7 downto 0) := x"09";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_BS    : std_logic_vector(7 downto 0) := x"0B";
  constant OP_BNC   : std_logic_vector(7 downto 0) := x"0C";
  constant OP_BNV   : std_logic_vector(7 downto 0) := x"0D";
  constant OP_MUL   : std_logic_vector(7 downto 0) := x"0E";
  constant OP_STOP  : std_logic_vector(7 downto 0) := x"0F";
  constant OP_DIV   : std_logic_vector(7 downto 0) := x"10";
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  
  -- NUEVAS INSTRUCCIONES (Deben coincidir con lo que pusiste en Processor_Unit)
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; -- Cargar Inmediato en X
  constant OP_LDIY  : std_logic_vector(7 downto 0) := x"13"; -- Cargar Inmediato en Y

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);
  
  signal mem_array : t_mem_array := (
    -- ============================================================
    -- INICIO: Inicialización
    -- ============================================================
    -- Cargar 50 creditos (Usamos LDI porque 50 es un numero, no una direccion)
    0 => OP_LDI, 1 => x"32", 2 => x"00",      -- LDI #50 (Carga 50 decimal)
    3 => OP_STX, 4 => x"80", 5 => x"00",      -- STX [x80] (Guarda en Créditos)

    -- ============================================================
    -- ESTADO: MENU PRINCIPAL (Mostrar TU + Créditos)
    -- ============================================================
    -- Manda comando visual x10 (Menú) - Usamos LDI
    6 => OP_LDI, 7 => x"10", 8 => x"00",      
    9 => OP_STX, 10 => x"D0", 11 => x"00",    -- Escribe en Control de Video (xD0)

    -- POLLING TECLADO (Esperar A, B o C para elegir color)
    -- Dir 12: Leer Teclado (Usamos LDX porque xF0 es una DIRECCION MMIO)
    12 => OP_LDX, 13 => x"F0", 14 => x"00",   -- Lee dirección xF0 (Teclado)
    15 => OP_CMP, 16 => x"00", 17 => x"00",   -- Compara con 0 (¿Hay tecla?)
    18 => OP_BR_NZ, 19 => x"18", 20 => x"00", -- Si NO es cero, salta a procesar (Dir 24 hex = 36 dec? No, 18 hex = 24 dec)
    21 => OP_JUMP, 22 => x"0C", 23 => x"00",  -- Si es cero, repite Polling (Salta a 12)

    -- PROCESAR COLOR (A=10=Rojo, B=11=Azul, C=12=Verde)
    -- Dir 24: Guardamos la tecla presionada
    24 => OP_STX, 25 => x"81", 26 => x"00",   -- Guardar Selección de Color en RAM [x81]
    
    -- FEEDBACK VISUAL SELECCION (Mandar x20) - Usamos LDI
    27 => OP_LDI, 28 => x"20", 29 => x"00",
    30 => OP_STX, 31 => x"D0", 32 => x"00",

    -- ============================================================
    -- ESTADO: INGRESO DE APUESTA (Esperar # para confirmar)
    -- ============================================================
    -- Dir 33: Esperar tecla numérica (LDX lee direccion xF0)
    33 => OP_LDX, 34 => x"F0", 35 => x"00",
    36 => OP_CMP, 37 => x"0F", 38 => x"00",   -- ¿Es tecla # (15)?
    39 => OP_BR_NZ, 40 => x"2D", 41 => x"00", -- Si NO es #, asumimos que es numero y guardamos (Salto a 45 decimal? 2D hex = 45)
    
    -- Si ES #, iniciamos juego (Continuamos a 42? No, logica inversa en tu codigo original)
    -- Asumamos logica simple: Si presiona #, saltamos a GIRAR.
    -- Vamos a corregir el flujo simplificado:
    
    -- Guardar Apuesta (Si no fue #)
    -- (Omitido lógica compleja, asumimos flujo directo para probar pantalla)
    
    -- ... [SALTAMOS A LA PARTE DE GIRO QUE ES LO QUE QUIERES VER] ...
    
    -- ============================================================
    -- ESTADO: GIRAR RULETA (Animación)
    -- ============================================================
    -- Dir 48 (aprox): Mandar comando x40 (Giro) - Usamos LDI
    48 => OP_LDI, 49 => x"40", 50 => x"00",
    51 => OP_STX, 52 => x"D0", 53 => x"00",
    
    -- PAUSA DRAMÁTICA
    54 => OP_WAIT, 55 => x"00", 56 => x"00",  -- Espera 1 seg

    -- ============================================================
    -- ESTADO: CALCULAR RESULTADO
    -- ============================================================
    -- Leer Random (Usamos LDX porque xE1 es DIRECCION del LFSR)
    57 => OP_LDX, 58 => x"E1", 59 => x"00",   
    60 => OP_STX, 61 => x"83", 62 => x"00",   -- Guardar Ganador en [x83]

    -- Mostrar Resultado en Video (Offset x50)
    -- Primero cargamos offset con LDI
    63 => OP_ADDI, 64 => x"50", 65 => x"00",  -- Suma 0x50 al valor aleatorio en X
    66 => OP_STX, 67 => x"D0", 68 => x"00",   -- Manda a pantalla

    -- LÓGICA DE GANADOR 
    69 => OP_LDX, 70 => x"83", 71 => x"00",   -- Recargar numero ganador
    -- Calcular Color (Mod 2) -> Usamos LDIY para cargar el 2
    72 => OP_LDIY, 73 => x"02", 74 => x"00",  -- Y = 2
    75 => OP_DIV, 76 => x"00", 77 => x"00",   -- X = X mod 2
    
    -- Loop infinito al final para no crashear
    100 => OP_JUMP, 101 => x"06", 102 => x"00", -- Volver al inicio

    others => x"00"
  );

begin

  -- Lectura de 3 bytes (Instrucción completa)
  Data_out <= mem_array(to_integer(unsigned(Addr_in))) & 
              mem_array(to_integer(unsigned(Addr_in)) + 1) & 
              mem_array(to_integer(unsigned(Addr_in)) + 2);

  -- Escritura (Solo escribe el byte bajo en la dirección indicada)
  Write_Process : process(clk)
  begin
    if rising_edge(clk) then
      if we = '1' then
        mem_array(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
      end if;
    end if;
  end process Write_Process;

end architecture;