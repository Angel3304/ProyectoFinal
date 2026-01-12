library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity Memoria_RAM is
    port(
        clk      : in  std_logic;
        we       : in  std_logic; -- Write Enable
        Addr_in  : in  std_logic_vector(7 downto 0);
        Data_in  : in  std_logic_vector(23 downto 0); 
        Data_out : out std_logic_vector(23 downto 0)
    );
end entity Memoria_RAM;

architecture Behavioral of Memoria_RAM is
    type t_ram_array is array (0 to 255) of std_logic_vector(7 downto 0);
    signal RAM_DATA : t_ram_array := (others => x"00");
begin
    
    -- Lectura (Asíncrona o combinacional para coincidir con tu diseño original)
    process(Addr_in, RAM_DATA)
        variable addr_int : integer;
    begin
        addr_int := to_integer(unsigned(Addr_in));
        if addr_int <= 253 then
            Data_out <= RAM_DATA(addr_int) & RAM_DATA(addr_int + 1) & RAM_DATA(addr_int + 2);
        else
            Data_out <= (others => '0');
        end if;
    end process;

    -- Escritura (Síncrona con el reloj)
    process(clk)
    begin
        if rising_edge(clk) then
            if we = '1' then
                -- Tu lógica original solo escribía los 8 bits bajos
                RAM_DATA(to_integer(unsigned(Addr_in))) <= Data_in(7 downto 0);
            end if;
        end if;
    end process;

end architecture;