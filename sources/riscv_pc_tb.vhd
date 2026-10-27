-------------------------------------------------------------------------------
-- Project  ELE8304 : Circuits intégrés à très grande échelle
-------------------------------------------------------------------------------
-- File     riscv_rf_tb.vhd
-- Author   Luc M'PO  <mpoluc@yahoo.com>
-- Date     2026-10-21
-------------------------------------------------------------------------------
-- Brief    Test Bench for Register File
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.riscv_pkg.all;

entity riscv_pc_tb is
end entity riscv_pc_tb;

architecture tb of riscv_pc_tb is

  constant CLK_PERIOD   : time    := 10 ns;
  constant RESET_VECTOR : natural := 16#00000100#;

  signal clk       : std_logic := '0';
  signal rstn      : std_logic := '0';
  signal stall     : std_logic := '0';
  signal transfert : std_logic := '0';
  signal target    : std_logic_vector(XLEN-1 downto 0) := (others => '0');
  signal pc        : std_logic_vector(XLEN-1 downto 0);

  signal sim_end : boolean := false;

begin

  
  dut : entity work.riscv_pc
    generic map (RESET_VECTOR => RESET_VECTOR)
    port map (
      i_clk       => clk,
      i_rstn      => rstn,
      i_stall     => stall,
      i_transfert => transfert,
      i_target    => target,
      o_pc        => pc);

  
  clk <= not clk after CLK_PERIOD/2 when not sim_end else '0';

  
  p_stim : process
    variable exp_pc : unsigned(XLEN-1 downto 0);
  begin

    
    rstn <= '0';
    wait until falling_edge(clk);
    exp_pc := to_unsigned(RESET_VECTOR, XLEN);
    assert unsigned(pc) = exp_pc
      report "Test 1 : pc different de RESET_VECTOR au reset" severity error;
    rstn <= '1';

    for i in 1 to 5 loop
      wait until falling_edge(clk);
      exp_pc := exp_pc + 4;
      assert unsigned(pc) = exp_pc
        report "Test 2 : mauvaise incrementation au cycle " & integer'image(i)
        severity error;
    end loop;

    stall <= '1';
    for i in 1 to 3 loop
      wait until falling_edge(clk);
      assert unsigned(pc) = exp_pc
        report "Test 3 : le PC a change pendant le stall" severity error;
    end loop;
    stall <= '0';

    transfert <= '1';
    target    <= x"00001000";
    wait until falling_edge(clk);
    transfert <= '0';
    exp_pc := x"00001000";
    assert unsigned(pc) = exp_pc
      report "Test 4 : le saut n'a pas ete fait" severity error;

    wait until falling_edge(clk);
    exp_pc := exp_pc + 4;
    assert unsigned(pc) = exp_pc
      report "Test 4 : mauvaise incrementation apres le saut" severity error;

    stall     <= '1';
    transfert <= '1';
    target    <= x"00002000";
    wait until falling_edge(clk);
    assert unsigned(pc) = exp_pc
      report "Test 5 : le stall n'a pas priorite sur le transfert"
      severity error;
    stall     <= '0';
    transfert <= '0';
    wait until falling_edge(clk);
    exp_pc := exp_pc + 4;
    assert unsigned(pc) = exp_pc
      report "Test 5 : mauvaise incrementation apres le stall" severity error;

    wait for CLK_PERIOD/4;
    rstn <= '0';
    wait for 1 ns;
    exp_pc := to_unsigned(RESET_VECTOR, XLEN);
    assert unsigned(pc) = exp_pc
      report "Test 6 : le reset n'est pas asynchrone" severity error;
    wait until falling_edge(clk);
    rstn <= '1';

    report "Fin de la simulation de riscv_pc_tb";
    sim_end <= true;
    wait;
  end process p_stim;

end architecture tb;