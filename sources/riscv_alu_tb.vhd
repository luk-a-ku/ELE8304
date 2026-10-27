
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library work;
use work.riscv_pkg.all;

entity riscv_alu_tb is
end entity riscv_alu_tb;

architecture tb of riscv_alu_tb is

    signal i_arith  : std_logic := '0';
    signal i_sign   : std_logic := '0';
    signal i_opcode : std_logic_vector(ALUOP_WIDTH-1 downto 0)
                      := ALUOP_ADD;
    signal i_shamt  : std_logic_vector(SHAMT_WIDTH-1 downto 0)
                      := (others => '0');
    signal i_src1   : std_logic_vector(XLEN-1 downto 0)
                      := (others => '0');
    signal i_src2   : std_logic_vector(XLEN-1 downto 0)
                      := (others => '0');
    signal o_res    : std_logic_vector(XLEN-1 downto 0);

begin

    dut : entity work.riscv_alu
        port map (
            i_arith  => i_arith,
            i_sign   => i_sign,
            i_opcode => i_opcode,
            i_shamt  => i_shamt,
            i_src1   => i_src1,
            i_src2   => i_src2,
            o_res    => o_res
        );

    stimulus : process
    begin

        -- Test 1 : ADD, 10 + 3 = 13
        i_opcode <= ALUOP_ADD;
        i_arith  <= '0';
        i_sign   <= '0';
        i_src1   <= x"0000000A";
        i_src2   <= x"00000003";
        wait for 1 ns;

        assert o_res = x"0000000D"
            report "ERREUR ALU : ADD"
            severity error;

        -- Test 2 : SUB, 10 - 3 = 7
        i_arith <= '1';
        wait for 1 ns;

        assert o_res = x"00000007"
            report "ERREUR ALU : SUB"
            severity error;

        -- Test 3 : XOR
        i_opcode <= ALUOP_XOR;
        i_src1   <= x"AAAAAAAA";
        i_src2   <= x"0F0F0F0F";
        wait for 1 ns;

        assert o_res = x"A5A5A5A5"
            report "ERREUR ALU : XOR"
            severity error;

        -- Test 4 : OR
        i_opcode <= ALUOP_OR;
        wait for 1 ns;

        assert o_res = x"AFAFAFAF"
            report "ERREUR ALU : OR"
            severity error;

        -- Test 5 : AND
        i_opcode <= ALUOP_AND;
        wait for 1 ns;

        assert o_res = x"0A0A0A0A"
            report "ERREUR ALU : AND"
            severity error;

        -- Test 6 : decalage a gauche, 1 << 4 = 16
        i_opcode <= ALUOP_SL;
        i_src1   <= x"00000001";
        i_shamt  <= std_logic_vector(to_unsigned(4, SHAMT_WIDTH));
        wait for 1 ns;

        assert o_res = x"00000010"
            report "ERREUR ALU : SLL"
            severity error;

        -- Test 7 : decalage logique a droite
        i_opcode <= ALUOP_SR;
        i_arith  <= '0';
        i_src1   <= x"80000000";
        i_shamt  <= std_logic_vector(to_unsigned(1, SHAMT_WIDTH));
        wait for 1 ns;

        assert o_res = x"40000000"
            report "ERREUR ALU : SRL"
            severity error;

        -- Test 8 : decalage arithmetique a droite
        i_arith <= '1';
        wait for 1 ns;

        assert o_res = x"C0000000"
            report "ERREUR ALU : SRA"
            severity error;

        -- Test 9 : comparaison signee, -1 < 1
        i_opcode <= ALUOP_SLT;
        i_sign   <= '1';
        i_src1   <= x"FFFFFFFF";
        i_src2   <= x"00000001";
        wait for 1 ns;

        assert o_res = x"00000001"
            report "ERREUR ALU : SLT signe"
            severity error;

        -- Test 10 : comparaison non signee, 3 < 10
        i_sign <= '0';
        i_src1 <= x"00000003";
        i_src2 <= x"0000000A";
        wait for 1 ns;

        assert o_res = x"00000001"
            report "ERREUR ALU : SLT non signe"
            severity error;

        report "Tests de l'ALU termines."
            severity note;

        stop;
        wait;

    end process stimulus;

end architecture tb;
