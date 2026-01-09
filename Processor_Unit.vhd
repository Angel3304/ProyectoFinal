library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.Seven_Segment_Pkg.all; 

entity Processor_Unit is
  port(
    master_clk      : in  std_logic;
    master_reset    : in  std_logic;
    master_run      : in  std_logic;
    
    -- PERIFÉRICOS
    i_key_code      : in  std_logic_vector(3 downto 0);
    i_key_valid     : in  std_logic;                    
    o_video_cmd     : out std_logic_vector(7 downto 0);

    -- SALIDAS
    o_flags         : out std_logic_vector(3 downto 0);
    
    -- DISPLAY
    o_seg_a, o_seg_b, o_seg_c, o_seg_d, o_seg_e, o_seg_f, o_seg_g, o_seg_dp : out std_logic;
    o_dig1, o_dig2, o_dig3, o_dig4 : out std_logic
  );
end entity Processor_Unit;

architecture Behavioral of Processor_Unit is
  
  -- Componentes (Mismos que tenías, solo declarados aquí)
  component Memory_Store_RAM is
    port(
      clk, we  : in std_logic;
      Addr_in  : in std_logic_vector(7 downto 0);
      Data_in  : in std_logic_vector(23 downto 0);
      Data_out : out std_logic_vector(23 downto 0) 
    );
  end component;
  
  component Arithmetic_Logic_Module is
    port (
      op_A, op_B : in std_logic_vector(15 downto 0);
      op_Sel : in std_logic_vector(3 downto 0);
      Result : out std_logic_vector(16 downto 0);
      z_out, s_out, c_out, ov_out : out std_logic
    );
  end component;

  component Divider_8bit is
    port (
      clk, rst, start : in std_logic;
      A_in, B_in : in std_logic_vector(7 downto 0);
      Q_out, R_out : out std_logic_vector(7 downto 0);
      done : out std_logic
    );
  end component;

  component Clock_Divider_Unit is
    port ( clk_in, rst_in : in std_logic;
           pulse_1khz_out, pulse_1hz_out : out std_logic );
  end component;

  -- FSM
  type t_fsm_state is (s_fetch_1, s_fetch_2, s_decode, s_execute, s_alu_writeback, 
                       s_load_x_1, s_load_x_2, s_load_y_1, s_load_y_2, s_wait_pulse, 
                       s_idle, s_div_start, s_div_wait, s_div_read, s_store_1);
  signal fsm_state : t_fsm_state := s_fetch_1;

  -- Señales CPU
  signal prog_counter  : unsigned(7 downto 0) := (others => '0');
  signal instr_reg     : std_logic_vector(23 downto 0);
  signal mem_addr_reg  : std_logic_vector(7 downto 0);
  signal mem_data_from_ram, mem_data_to_ram, data_bus_mux_out : std_logic_vector(23 downto 0);
  signal mem_we : std_logic := '0';

  signal op_code, operand_1, operand_2 : std_logic_vector(7 downto 0);
  signal reg_X, reg_Y : std_logic_vector(15 downto 0) := (others => '0');

  signal arith_in_A, arith_in_B : std_logic_vector(15 downto 0);
  signal arith_op_sel : std_logic_vector(3 downto 0);
  signal arith_out : std_logic_vector(16 downto 0);
  signal z_flag_alu, s_flag_alu, c_flag_alu, ov_flag_alu : std_logic;
  signal status_register : std_logic_vector(3 downto 0) := "0000";
  
  -- Display
  signal output_buffer, bcd_value, display_data : std_logic_vector(15 downto 0) := (others => '0');
  signal pulse_1khz, pulse_1hz, pulse_1hz_last, pulse_1khz_last : std_logic;
  signal digit_selector : unsigned(1 downto 0);
  signal cathode_segments : std_logic_vector(6 downto 0);
  signal anode_enable : std_logic_vector(3 downto 0);

  -- Divider
  signal div_start, div_done : std_logic;
  signal div_quotient, div_remainder : std_logic_vector(7 downto 0);

  -- MMIO Addresses
  constant IO_ADDR_KEYPAD : std_logic_vector(7 downto 0) := x"F0";
  constant IO_ADDR_RANDOM : std_logic_vector(7 downto 0) := x"E1";
  constant IO_ADDR_LEDS   : std_logic_vector(7 downto 0) := x"E0";
  constant IO_ADDR_VIDEO  : std_logic_vector(7 downto 0) := x"D0";

  -- Peripherals
  signal lfsr_value : std_logic_vector(7 downto 0);
  signal leds_reg : std_logic_vector(4 downto 0) := (others => '0');
  signal video_ctrl_reg : std_logic_vector(7 downto 0) := x"10";
  
  signal lfsr_reset_n : std_logic;
  signal internal_key_buffer : std_logic_vector(3 downto 0) := (others => '0');

begin

	lfsr_reset_n <= not master_reset;
	Key_Latch_Process : process(master_clk)
		begin
			 if rising_edge(master_clk) then
				  if master_reset = '0' then
						internal_key_buffer <= (others => '0');
				  elsif i_key_valid = '1' then
						-- Guardamos el dato apenas llegue el pulso de valid
						internal_key_buffer <= i_key_code;
				  end if;
			 end if;
		end process;

  -- Mapeo de Componentes
  U_Mem : Memory_Store_RAM 
		port map (
			clk => master_clk, 
			we => mem_we,
			Addr_in => mem_addr_reg, 
			Data_in => mem_data_to_ram, 
			Data_out => mem_data_from_ram);
  U_ALM : Arithmetic_Logic_Module port map (
			op_A => arith_in_A, 
			op_B => arith_in_B, 
			op_Sel => arith_op_sel, 
			Result => arith_out, 
			z_out => z_flag_alu, 
			s_out => s_flag_alu, 
			c_out => c_flag_alu, 
			ov_out => ov_flag_alu);
  U_Div : Divider_8bit port map (
			clk => master_clk, 
			rst => master_reset, 
			start => div_start, 
			A_in => reg_X(7 downto 0), 
			B_in => reg_Y(7 downto 0), 
			Q_out => div_quotient, 
			R_out => div_remainder, 
			done => div_done);
  U_Clk_Div : Clock_Divider_Unit port map (
			clk_in => master_clk, 
			rst_in => master_reset, 
			pulse_1khz_out => pulse_1khz, 
			pulse_1hz_out => pulse_1hz);
  U_LFSR : entity work.LFSR_8bit port map (
			clk => master_clk, 
			reset => lfsr_reset_n, 
			enable => '1', 
			q => lfsr_value);

  -- MMIO Read Logic
  data_bus_mux_out <= 
      x"0000" & lfsr_value        when mem_addr_reg = IO_ADDR_RANDOM else
      x"00000" & x"5" when mem_addr_reg = IO_ADDR_KEYPAD else -- <--- CORRECCIÓN: Lee el Buffer
      mem_data_from_ram;

  -- Outputs
  o_flags  <= status_register;
  o_video_cmd <= video_ctrl_reg;
  
  op_code <= instr_reg(23 downto 16);
  operand_1 <= instr_reg(15 downto 8);
  operand_2 <= instr_reg(7 downto 0);

  -- Main FSM
  FSM_Process : process(master_clk)
  begin
    if rising_edge(master_clk) then
      pulse_1hz_last <= pulse_1hz;
      div_start <= '0';
      mem_we <= '0'; 
      
      if master_reset = '0' then -- (Ojo con esta polaridad, la revisaremos luego)
    prog_counter <= (others => '0');
    fsm_state <= s_fetch_1;
    reg_X <= (others => '0'); reg_Y <= (others => '0');
    status_register <= (others => '0');
    leds_reg <= (others => '0');
    
    -- CAMBIOS PARA DIAGNÓSTICO:
    video_ctrl_reg <= x"20";          -- x20 = Barras de Colores (No la 'A')
    output_buffer  <= x"8888";        -- Display muestra 8888 en lugar de 0000
        
      elsif master_run = '1' then
        -- PAUSA si master_run es '1' (Eliminar esta línea si quieres que corra siempre o controla bien el switch)
        null; 
      else
        case fsm_state is
          when s_fetch_1 => mem_addr_reg <= std_logic_vector(prog_counter); fsm_state <= s_fetch_2;
          -- Incrementamos 3 bytes porque cada instrucción ocupa 3 direcciones de memoria
			 when s_fetch_2 => instr_reg <= data_bus_mux_out; prog_counter <= prog_counter + 3; fsm_state <= s_decode;
          
          when s_decode =>
            arith_op_sel <= (others => '0');
            case op_code is
              when x"01" => fsm_state <= s_load_x_1;
              when x"02" => fsm_state <= s_load_y_1;
              when x"03" | x"04" | x"05" | x"06" | x"09" | x"0E" | x"07" | x"08" | x"0B" | x"0C" | x"0D" | x"12" | x"13"=> fsm_state <= s_execute;
              when x"0A" => prog_counter <= prog_counter - 3; fsm_state <= s_wait_pulse; -- WAIT
				  when x"0F" => prog_counter <= prog_counter - 3; fsm_state <= s_idle;       -- STOP
				  when x"10" => prog_counter <= prog_counter - 3; fsm_state <= s_div_start; -- DIV (mantiene PC hasta terminar)
              when x"11" => fsm_state <= s_store_1;
              when others => fsm_state <= s_fetch_1;
            end case;

          when s_execute =>
            fsm_state <= s_fetch_1;
            case op_code is
              when x"03" => arith_in_A <= reg_X; arith_in_B <= reg_Y; arith_op_sel <= "0110"; fsm_state <= s_alu_writeback;
              when x"04" => arith_in_A <= reg_X; arith_in_B <= x"00" & operand_2; arith_op_sel <= "0110"; fsm_state <= s_alu_writeback;
              when x"05" | x"09" => arith_in_A <= reg_X; arith_in_B <= reg_Y; arith_op_sel <= "0111"; fsm_state <= s_alu_writeback;
              when x"0E" => arith_in_A <= reg_X; arith_in_B <= reg_Y; arith_op_sel <= "1000"; fsm_state <= s_alu_writeback;
              when x"06" => output_buffer <= reg_X;
              when x"07" => prog_counter <= unsigned(operand_1);
              when x"08" => if status_register(3) = '0' then prog_counter <= unsigned(operand_1); end if;
              when x"0B" => if status_register(2) = '1' then prog_counter <= unsigned(operand_1); end if;
              when x"0C" => if status_register(1) = '0' then prog_counter <= unsigned(operand_1); end if;
              when x"0D" => if status_register(0) = '0' then prog_counter <= unsigned(operand_1); end if;
				  when x"12" => reg_X <= x"00" & operand_1; -- LDI #Num (Carga numero directo a X)
				  when x"13" => reg_Y <= x"00" & operand_1; -- LDIY #Num (Carga numero directo a Y)
              when others => null;
            end case;

          when s_alu_writeback =>
            if op_code = x"03" or op_code = x"04" or op_code = x"09" or op_code = x"0E" then reg_X <= arith_out(15 downto 0); end if;
            status_register(3) <= z_flag_alu; status_register(2) <= s_flag_alu; status_register(1) <= c_flag_alu; status_register(0) <= ov_flag_alu;
            fsm_state <= s_fetch_1;

          when s_load_x_1 => mem_addr_reg <= operand_1; fsm_state <= s_load_x_2;
          when s_load_x_2 => reg_X <= data_bus_mux_out(15 downto 0); fsm_state <= s_fetch_1;
          when s_load_y_1 => mem_addr_reg <= operand_1; fsm_state <= s_load_y_2;
          when s_load_y_2 => reg_Y <= data_bus_mux_out(15 downto 0); fsm_state <= s_fetch_1;
          
          -- Sumamos 3 para avanzar a la siguiente instrucción real
			 when s_wait_pulse => if pulse_1hz = '1' and pulse_1hz_last = '0' then prog_counter <= prog_counter + 3; fsm_state <= s_fetch_1; end if;
          when s_idle => null;
          when s_div_start => div_start <= '1'; fsm_state <= s_div_wait;
          when s_div_wait => if div_done = '1' then fsm_state <= s_div_read; end if;
          
          when s_div_read =>
            reg_X <= x"00" & div_quotient; reg_Y <= x"00" & div_remainder; status_register <= "0000";
            if unsigned(div_quotient) = 0 then status_register(3) <= '1'; end if;
            status_register(2) <= div_quotient(7); prog_counter <= prog_counter + 3; fsm_state <= s_fetch_1;

          when s_store_1 =>
            if operand_1 = IO_ADDR_LEDS then leds_reg <= reg_X(4 downto 0); mem_we <= '0';
            elsif operand_1 = IO_ADDR_VIDEO then video_ctrl_reg <= reg_X(7 downto 0); mem_we <= '0';
            else mem_addr_reg <= operand_1; mem_data_to_ram <= x"00" & reg_X; mem_we <= '1';
            end if;
            fsm_state <= s_fetch_1;
          when others => fsm_state <= s_idle;
        end case;
      end if;
    end if;
  end process FSM_Process;

  -- 7 Segment Multiplexing logic remains the same...
  Mux_Tick_Gen : process(master_clk) 
  begin 
		if rising_edge(master_clk) then 
			pulse_1khz_last <= pulse_1khz; 
		if master_reset = '0' then 
			digit_selector <= "00"; 
			pulse_1khz_last <= '0'; 
		else 
			if pulse_1khz = '1' and pulse_1khz_last = '0' then 
				digit_selector <= digit_selector + 1; 
			end if; 
		end if; 
		end if; 
end process Mux_Tick_Gen;
  display_data <= bcd_value;
  Bin_to_BCD_Convert : process(output_buffer) variable bcd_temp : std_logic_vector(15 downto 0); variable bin_temp : std_logic_vector(15 downto 0); begin bcd_temp := (others => '0'); bin_temp := output_buffer; for i in 0 to 15 loop if bcd_temp(3 downto 0) > "0100" then bcd_temp(3 downto 0) := std_logic_vector(unsigned(bcd_temp(3 downto 0)) + 3); end if; if bcd_temp(7 downto 4) > "0100" then bcd_temp(7 downto 4) := std_logic_vector(unsigned(bcd_temp(7 downto 4)) + 3); end if; if bcd_temp(11 downto 8) > "0100" then bcd_temp(11 downto 8) := std_logic_vector(unsigned(bcd_temp(11 downto 8)) + 3); end if; if bcd_temp(15 downto 12) > "0100" then bcd_temp(15 downto 12) := std_logic_vector(unsigned(bcd_temp(15 downto 12)) + 3); end if; bcd_temp(15 downto 1) := bcd_temp(14 downto 0); bcd_temp(0) := bin_temp(15); bin_temp(15 downto 0) := bin_temp(14 downto 0) & '0'; end loop; bcd_value <= bcd_temp; end process Bin_to_BCD_Convert;
  Display_Driver : process(digit_selector, display_data) variable current_digit_data : std_logic_vector(3 downto 0); begin case to_integer(digit_selector) is when 0 => anode_enable <= "1110"; current_digit_data := display_data(3 downto 0); when 1 => anode_enable <= "1101"; current_digit_data := display_data(7 downto 4); when 2 => anode_enable <= "1011"; current_digit_data := display_data(11 downto 8); when others => anode_enable <= "0111"; current_digit_data := display_data(15 downto 12); end case; cathode_segments <= decode_to_segments(current_digit_data); end process Display_Driver;
  o_seg_dp <= '1'; o_seg_a <= cathode_segments(6); o_seg_b <= cathode_segments(5); o_seg_c <= cathode_segments(4); o_seg_d <= cathode_segments(3); o_seg_e <= cathode_segments(2); o_seg_f <= cathode_segments(1); o_seg_g <= cathode_segments(0); o_dig1 <= anode_enable(0); o_dig2 <= anode_enable(1); o_dig3 <= anode_enable(2); o_dig4 <= anode_enable(3);

end architecture Behavioral;