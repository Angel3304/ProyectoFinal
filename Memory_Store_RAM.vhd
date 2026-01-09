library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memory_Store_RAM is
    port(
        clk, we  : in std_logic;
        Addr_in  : in std_logic_vector(7 downto 0);
        Data_in  : in std_logic_vector(23 downto 0); 
        Data_out : out std_logic_vector(23 downto 0) 
    );
end entity Memory_Store_RAM;

architecture Behavioral of Memory_Store_RAM is

  -- OPCODES
  constant OP_LDX   : std_logic_vector(7 downto 0) := x"01";
  constant OP_LDY   : std_logic_vector(7 downto 0) := x"02";
  constant OP_CMP   : std_logic_vector(7 downto 0) := x"05";
  constant OP_DISP  : std_logic_vector(7 downto 0) := x"06";
  constant OP_JUMP  : std_logic_vector(7 downto 0) := x"07";
  constant OP_BR_NZ : std_logic_vector(7 downto 0) := x"08";
  constant OP_WAIT  : std_logic_vector(7 downto 0) := x"0A";
  constant OP_STX   : std_logic_vector(7 downto 0) := x"11";
  constant OP_LDI   : std_logic_vector(7 downto 0) := x"12"; 

  type t_mem_array is array (0 to 255) of std_logic_vector(7 downto 0);

  -- 1. ROM: CÓDIGO DEL JUEGO (Fijo)
  constant ROM_CODE : t_mem_array := (
    -- INICIO: Cargar 50 (x32) en Saldo [x80]
    0 => OP_LDI, 1 => x"32", 2 => x"00",      
    3 => OP_STX, 4 => x"80", 5 => x"00",      

    -- MENÚ PRINCIPAL: Mostrar Saldo
    6 => OP_LDX, 7 => x"80", 8 => x"00",   
    9 => OP_DISP, 10 => x"00", 11 => x"00", 
    
    -- Matriz en modo "Menú" (x10)
    12 => OP_LDI, 13 => x"10", 14 => x"00",
    15 => OP_STX, 16 => x"D0", 17 => x"00", 

    -- LEER APUESTA
    18 => OP_LDX, 19 => x"F0", 20 => x"00", 
    21 => OP_CMP, 22 => x"00", 23 => x"00", 
    24 => OP_BR_NZ, 25 => x"1E", 26 => x"00", -- Ir a 30
    27 => OP_JUMP, 28 => x"12", 29 => x"00",  -- Loop a 18

    -- JUEGO (Dir 30)
    30 => OP_STX, 31 => x"82", 32 => x"00", -- Guardar elección
    33 => OP_DISP, 34 => x"00", 35 => x"00", -- Mostrar
    
    -- GIRAR (x20)
    36 => OP_LDI, 37 => x"20", 38 => x"00",
    39 => OP_STX, 40 => x"D0", 41 => x"00",
    
    42 => OP_WAIT, 43 => x"00", 44 => x"00", 
    45 => OP_WAIT, 46 => x"00", 47 => x"00",

    -- RESULTADO
    48 => OP_LDX, 49 => x"E1", 50 => x"00", 
    51 => OP_STX, 52 => x"83", 53 => x"00", 
    54 => OP_DISP, 55 => x"00", 56 => x"00", 

    -- VERIFICAR
    57 => OP_LDY, 58 => x"82", 59 => x"00", 
    60 => OP_CMP, 61 => x"00", 62 => x"00", 
    63 => OP_BR_NZ, 64 => x"51", 65 => x"00", -- Ir a 81 si pierde

    -- GANASTE (Dir 66)
    66 => OP_LDI, 67 => x"40", 68 => x"00", 
    69 => OP_STX, 70 => x"D0", 71 => x"00",
    
    -- PREMIO: 99
    72 => OP_LDI, 73 => x"99", 74 => x"00",
    75 => OP_STX, 76 => x"80", 77 => x"00",
    
    78 => OP_JUMP, 79 => x"5D", 80 => x"00", -- Ir a 93

    -- PERDISTE (Dir 81)
    81 => OP_LDI, 82 => x"50", 83 => x"00", 
    84 => OP_STX, 85 => x"D0", 86 => x"00",
    
    -- PENA: 10
    87 => OP_LDI, 88 => x"0A", 89 => x"00",
    90 => OP_STX, 91 => x"80", 92 => x"00",

    -- RESET (Dir 93)
    93 => OP_WAIT, 94 => x"00", 95 => x"00",
    96 => OP_JUMP, 97 => x"06", 98 => x"00", 

    others => x"00"
  );

  -- Función para inicializar la RAM con valores específicos
    function init_ram return t_mem_array is
        variable temp_ram : t_mem_array := (others => x"00");
    begin
        -- Inicializamos la dirección 128 (x80) con 50 (x32)
        temp_ram(128) := x"32"; 
        return temp_ram;
    end function;

    -- Usamos la función para crear la señal con el 50 ya cargado
    signal RAM_DATA : t_mem_array := init_ram;

begin

    -- PROCESO DE LECTURA CORREGIDO (Sin ROM_CODE en la lista)
    process(Addr_in, RAM_DATA) 
        variable addr_int : integer;
        variable b0, b1, b2 : std_logic_vector(7 downto 0);
    begin
        addr_int := to_integer(unsigned(Addr_in));
        
        -- Combinamos ROM (Código) y RAM (Datos)
        -- ROM_CODE se usa dentro, pero no va en la lista de arriba porque es constante.
        b0 := ROM_CODE(addr_int)     or RAM_DATA(addr_int);
        b1 := ROM_CODE(addr_int + 1) or RAM_DATA(addr_int + 1);
        b2 := ROM_CODE(addr_int + 2) or RAM_DATA(addr_int + 2);
        
        Data_out <= b0 & b1 & b2;
    end process;

    -- PROCESO DE ESCRITURA
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;

end architecture;