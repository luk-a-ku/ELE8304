
-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-- File     riscv_pc_tb.vhd
-- Author   Khalil Ben Salem
-- Date     2026-10-26
-- Description : Testbench du compteur de programme
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use std.env.all;

library work;
use work.riscv_pkg.all;

entity riscv_pc_tb is
end entity riscv_pc_tb;

architecture tb of riscv_pc_tb is

    constant PERIOD : time := 10 ns;

    constant RESET_PC : std_logic_vector(XLEN-1 downto 0)
        := std_logic_vector(unsigned(RESET));

    constant TARGET_PC : std_logic_vector(XLEN-1 downto 0)
        := std_logic_vector(to_unsigned(16#100#, XLEN));

    signal clk       : std_logic := '0';
    signal rstn      : std_logic := '0';
    signal stall     : std_logic := '0';
    signal transfert : std_logic := '0';
    signal target    : std_logic_vector(XLEN-1 downto 0)
        := (others => '0');
    signal pc        : std_logic_vector(XLEN-1 downto 0);

begin

    -- Instance du PC à tester
    dut : entity work.riscv_pc
        generic map (
            RESET_VECTOR => 0
        )
        port map (
            i_clk       => clk,
            i_rstn      => rstn,
            i_stall     => stall,
            i_transfert => transfert,
            i_target    => target,
            o_pc        => pc
        );

    -- Génération de l'horloge : période de 10 ns
    clk <= not clk after PERIOD/2;

    stimulus : process
    begin

        -- Test 1 : remise à zéro asynchrone
        rstn      <= '0';
        stall     <= '0';
        transfert <= '0';

        wait for 2*PERIOD;
        wait for 1 ns;

        assert pc = RESET_PC
            report "ERREUR PC : remise a zero"
            severity error;

        -- Libérer le reset
        rstn <= '1';

        -- Test 2 : premier incrément
        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = std_logic_vector(unsigned(RESET_PC) + ADDR_INCR)
            report "ERREUR PC : premier increment"
            severity error;

        -- Test 3 : deuxième incrément
        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = std_logic_vector(unsigned(RESET_PC) + 2*ADDR_INCR)
            report "ERREUR PC : deuxieme increment"
            severity error;

        -- Test 4 : stall bloque le PC
        stall <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = std_logic_vector(unsigned(RESET_PC) + 2*ADDR_INCR)
            report "ERREUR PC : stall"
            severity error;

        -- Test 5 : stall prioritaire sur transfert
        target    <= TARGET_PC;
        transfert <= '1';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = std_logic_vector(unsigned(RESET_PC) + 2*ADDR_INCR)
            report "ERREUR PC : priorite du stall"
            severity error;

        -- Test 6 : transfert lorsque stall vaut zero
        stall <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = TARGET_PC
            report "ERREUR PC : chargement de la cible"
            severity error;

        -- Test 7 : reprise de l'incrémentation
        transfert <= '0';

        wait until rising_edge(clk);
        wait for 1 ns;

        assert pc = std_logic_vector(unsigned(TARGET_PC) + ADDR_INCR)
            report "ERREUR PC : increment apres transfert"
            severity error;

        -- Test 8 : remise à zéro pendant le fonctionnement
        rstn <= '0';
        wait for 1 ns;

        assert pc = RESET_PC
            report "ERREUR PC : reset asynchrone en fonctionnement"
            severity error;

        report "Tests du PC termines." severity note;

        stop;
        wait;

    end process stimulus;

end architecture tb;
