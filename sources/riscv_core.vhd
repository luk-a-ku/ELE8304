-------------------------------------------------------------------------------
-- ELE8304 - Mini-RISC-V : pipeline IF / ID / EX / ME / WB + ESWP
-------------------------------------------------------------------------------
-- IF : le PC presente une adresse en OCTETS a la memoire d'instructions.
-- ID : decode les 25 instructions du mini-RISC-V et ESWP ; lit rs1/rs2.
-- EX : forwarding, ALU, branchements/sauts, calcul d'adresse, conversion ESWP.
-- ME : acces memoire pour LW/SW ; conservation du resultat pour les autres.
-- WB : selection memoire/resultat et ecriture dans rd (sauf x0).
--
-- A chaque front, des instructions DIFFERENTES avancent simultanement.
-- On transporte les commandes, rd et la validite avec les donnees associees.
-- Apres remplissage : idealement une instruction terminee par cycle.
--
-- Adaptation aux fichiers fournis :
-- * dpm memorise deja l'adresse au front : i_imem_read est l'instruction ID.
--   On enregistre seulement le PC associe et la validite a la frontiere IF/ID.
-- * riscv_rf lit au front : ses sorties correspondent a l'instruction EX.
--   Ne pas ajouter un registre supplementaire entre ces sorties et EX.
-- * i_dmem_read correspond en WB a la demande emise en ME au front precedent.
-- * Le testbench divise deja les adresses par 4 : ne pas le refaire ici.
-- * Les ports d'adresse restent sur 9 bits, comme dans l'interface imposee.
--
-- Conflits :
-- * Forwarding ME puis WB vers EX, priorite au producteur le plus recent.
-- * Load-use : geler PC/ID, injecter une bulle en EX ; ME/WB continuent.
-- * Saut pris en EX : rediriger le PC et invalider les deux instructions
--   plus jeunes (ID et la lecture en cours). Prediction BEQ : non pris.
-- * Toutes les ecritures sont conditionnees par valid et le type d'instruction.
--
-- ESWP opcode 1010101, format I :
-- * funct3(2)=0 : rs1 ; funct3(2)=1 : immediat I etendu avec signe sur 32 bits.
--   On interprete ici 'positif' comme non negatif, donc 000 utilise rs1.
-- * funct3(0)=0 : LE->BE ; =1 : BE->LE. Meme permutation dans les deux sens.
-- * Le resultat traverse ME/WB et les chemins de forwarding comme un ADD.
--
-- Les instructions non reconnues sont traitees comme des bulles, sans trap.
-- DFT non implemente (facultatif au TP) : interface conservee, o_tdo a zero.
-------------------------------------------------------------------------------
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
library work;
use work.riscv_pkg.all;

entity riscv_core is
    port (
        i_rstn       : in  std_logic;
        i_clk        : in  std_logic;
        o_imem_en    : out std_logic;
        o_imem_addr  : out std_logic_vector(8 downto 0);
        i_imem_read  : in  std_logic_vector(31 downto 0);
        o_dmem_en    : out std_logic;
        o_dmem_we    : out std_logic;
        o_dmem_addr  : out std_logic_vector(8 downto 0);
        i_dmem_read  : in  std_logic_vector(31 downto 0);
        o_dmem_write : out std_logic_vector(31 downto 0);
        i_scan_en    : in  std_logic;
        i_test_mode  : in  std_logic;
        i_tdi        : in  std_logic;
        o_tdo        : out std_logic
    );
end entity riscv_core;

architecture beh of riscv_core is
    subtype word_t is std_logic_vector(XLEN-1 downto 0);
    subtype reg_t is std_logic_vector(REG_WIDTH-1 downto 0);
    constant ZERO : word_t := (others => '0');
    constant OP_LUI   : std_logic_vector(6 downto 0) := "0110111";
    constant OP_JAL   : std_logic_vector(6 downto 0) := "1101111";
    constant OP_JALR  : std_logic_vector(6 downto 0) := "1100111";
    constant OP_BEQ   : std_logic_vector(6 downto 0) := "1100011";
    constant OP_LOAD  : std_logic_vector(6 downto 0) := "0000011";
    constant OP_STORE : std_logic_vector(6 downto 0) := "0100011";
    constant OP_IMM   : std_logic_vector(6 downto 0) := "0010011";
    constant OP_REG   : std_logic_vector(6 downto 0) := "0110011";
    constant OP_ESWP  : std_logic_vector(6 downto 0) := "1010101";

    -- Un record regroupe les commandes pour eviter de desynchroniser les champs.
    type control_t is record
        valid, regwrite, memread, memwrite : std_logic;
        use_rs1, use_rs2, src2_imm : std_logic;
        branch_eq, jump, jump_reg, eswp, eswp_imm : std_logic;
        arith, sign_ext : std_logic;
        aluop : std_logic_vector(ALUOP_WIDTH-1 downto 0);
        rs1, rs2, rd : reg_t;
        imm, pc : word_t;
    end record;
    constant BUBBLE : control_t := (
        valid=>'0', regwrite=>'0', memread=>'0', memwrite=>'0',
        use_rs1=>'0', use_rs2=>'0', src2_imm=>'0',
        branch_eq=>'0', jump=>'0', jump_reg=>'0', eswp=>'0', eswp_imm=>'0',
        arith=>'0', sign_ext=>'0', aluop=>ALUOP_ADD,
        rs1=>REG_X0, rs2=>REG_X0, rd=>REG_X0, imm=>ZERO, pc=>ZERO);

    signal pc_if, pc_id, instr_id : word_t;
    signal valid_id : std_logic := '0';
    signal decoded, ex : control_t := BUBBLE;
    signal stall_if, load_use, redirect : std_logic;
    signal target_pc : word_t;
    signal rf_a, rf_b, source_a, source_b : word_t;
    signal alu_a, alu_b, alu_result, eswp_in, eswp_result, result_ex : word_t;
    signal rs1_id, rs2_id : reg_t;

    -- EX/ME : informations de l'instruction a l'etage ME.
    signal valid_me, regwrite_me, memread_me, memwrite_me : std_logic := '0';
    signal rd_me : reg_t := REG_X0;
    signal result_me, store_me : word_t := ZERO;

    -- ME/WB : la sortie synchrone dpm fournit directement la donnee de LW.
    signal valid_wb, regwrite_wb, memread_wb : std_logic := '0';
    signal rd_wb : reg_t := REG_X0;
    signal result_wb, data_wb : word_t := ZERO;
    signal reg_we_wb : std_logic;

begin
    ---------------------------------------------------------------------------
    -- IF : PC et lecture memoire ; priorite au saut sur le stall.
    ---------------------------------------------------------------------------
    stall_if <= load_use and not redirect;
    u_pc : entity work.riscv_pc
        generic map (RESET_VECTOR => RESET_VECTOR)
        port map (i_clk=>i_clk, i_rstn=>i_rstn, i_stall=>stall_if,
                  i_transfert=>redirect, i_target=>target_pc, o_pc=>pc_if);
    o_imem_en   <= i_rstn and not stall_if;
    o_imem_addr <= pc_if(8 downto 0);
    instr_id    <= i_imem_read;

    p_if_id : process(i_clk, i_rstn)
    begin
        if i_rstn='0' then
            pc_id <= RESET;
            valid_id <= '0';
        elsif rising_edge(i_clk) then
            if redirect='1' then
                -- La memoire vient de lire l'ancienne adresse IF : on l'annule.
                pc_id <= pc_if;
                valid_id <= '0';
            elsif stall_if='0' then
                pc_id <= pc_if;
                valid_id <= '1';
            end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- ID : decodeur combinatoire. Valeurs par defaut = bulle, aucun latch.
    ---------------------------------------------------------------------------
    p_decode : process(all)
        variable c : control_t;
        variable op : std_logic_vector(6 downto 0);
        variable f3 : std_logic_vector(2 downto 0);
        variable f7 : std_logic_vector(6 downto 0);
        variable legal : boolean;
    begin
        c := BUBBLE;
        op := instr_id(6 downto 0);
        f3 := instr_id(14 downto 12);
        f7 := instr_id(31 downto 25);
        legal := true;
        c.pc := pc_id;
        c.rs1 := instr_id(19 downto 15);
        c.rs2 := instr_id(24 downto 20);
        c.rd := instr_id(11 downto 7);
        c.imm := std_logic_vector(resize(signed(instr_id(31 downto 20)), XLEN));
        case op is
            when OP_LUI =>
                c.regwrite := '1'; c.src2_imm := '1'; c.aluop := ALUOP_OTHER;
                c.imm := instr_id(31 downto 12) & x"000";
            when OP_JAL =>
                c.regwrite := '1'; c.jump := '1';
                c.imm := std_logic_vector(resize(signed(instr_id(31) &
                    instr_id(19 downto 12) & instr_id(20) &
                    instr_id(30 downto 21) & '0'), XLEN));
            when OP_JALR =>
                legal := f3="000";
                c.regwrite := '1'; c.jump := '1'; c.jump_reg := '1';
                c.use_rs1 := '1';
            when OP_BEQ =>
                legal := f3="000";
                c.branch_eq := '1'; c.use_rs1 := '1'; c.use_rs2 := '1';
                c.imm := std_logic_vector(resize(signed(instr_id(31) &
                    instr_id(7) & instr_id(30 downto 25) &
                    instr_id(11 downto 8) & '0'), XLEN));
            when OP_LOAD =>
                legal := f3="010";
                c.use_rs1 := '1'; c.src2_imm := '1';
                c.memread := '1'; c.regwrite := '1';
            when OP_STORE =>
                legal := f3="010";
                c.use_rs1 := '1'; c.use_rs2 := '1'; c.src2_imm := '1';
                c.memwrite := '1';
                c.imm := std_logic_vector(resize(signed(
                    instr_id(31 downto 25) & instr_id(11 downto 7)), XLEN));
            when OP_REG | OP_IMM =>
                c.regwrite := '1'; c.use_rs1 := '1';
                if op=OP_IMM then c.src2_imm := '1';
                else c.use_rs2 := '1'; end if;
                case f3 is
                    when "000" =>
                        c.aluop := ALUOP_ADD;
                        if op=OP_REG then
                            legal := f7="0000000" or f7="0100000";
                            c.arith := instr_id(30);
                        end if;
                    when "001" =>
                        c.aluop := ALUOP_SL;
                        legal := f7="0000000";
                    when "010" =>
                        c.aluop := ALUOP_SLT; c.arith := '1'; c.sign_ext := '1';
                        if op=OP_REG then legal := f7="0000000"; end if;
                    when "011" =>
                        c.aluop := ALUOP_SLT; c.arith := '1';
                        if op=OP_REG then legal := f7="0000000"; end if;
                    when "100" =>
                        c.aluop := ALUOP_XOR;
                        if op=OP_REG then legal := f7="0000000"; end if;
                    when "101" =>
                        c.aluop := ALUOP_SR; c.arith := instr_id(30);
                        legal := f7="0000000" or f7="0100000";
                    when "110" =>
                        c.aluop := ALUOP_OR;
                        if op=OP_REG then legal := f7="0000000"; end if;
                    when "111" =>
                        c.aluop := ALUOP_AND;
                        if op=OP_REG then legal := f7="0000000"; end if;
                    when others => legal := false;
                end case;
            when OP_ESWP =>
                c.eswp := '1'; c.regwrite := '1';
                c.eswp_imm := f3(2);
                c.use_rs1 := not f3(2);
                -- f3(0) indique le sens. La permutation est la meme pour les
                -- deux sens ; aucun multiplexeur de sens n'est necessaire.
            when others => legal := false;
        end case;
        if legal and valid_id='1' then c.valid := '1';
        else c := BUBBLE; end if;
        decoded <= c;
    end process;

    rs1_id <= decoded.rs1 when decoded.use_rs1='1' else REG_X0;
    rs2_id <= decoded.rs2 when decoded.use_rs2='1' else REG_X0;
    u_rf : entity work.riscv_rf
        port map (i_clk=>i_clk, i_rstn=>i_rstn,
            i_addr_ra=>rs1_id, o_data_ra=>rf_a,
            i_addr_rb=>rs2_id, o_data_rb=>rf_b,
            i_we=>reg_we_wb, i_addr_w=>rd_wb, i_data_w=>data_wb);

    ---------------------------------------------------------------------------
    -- Load-use : EX contient LW, ID veut utiliser sa destination.
    -- Un seul cycle d'attente ; exclure x0 et les champs non utilises.
    ---------------------------------------------------------------------------
    load_use <= '1' when ex.valid='1' and ex.memread='1' and
        ex.rd/=REG_X0 and decoded.valid='1' and
        ((decoded.use_rs1='1' and decoded.rs1=ex.rd) or
         (decoded.use_rs2='1' and decoded.rs2=ex.rd)) else '0';

    p_id_ex : process(i_clk, i_rstn)
    begin
        if i_rstn='0' then ex <= BUBBLE;
        elsif rising_edge(i_clk) then
            if redirect='1' or load_use='1' then ex <= BUBBLE;
            else ex <= decoded; end if;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- EX : forwarding pour ALU, comparaison, JALR, SW et ESWP.
    -- ME a priorite sur WB ; le resultat d'un LW en ME est encore une adresse.
    ---------------------------------------------------------------------------
    p_forward : process(all)
        variable a, b : word_t;
    begin
        a := ZERO; b := ZERO;
        if ex.use_rs1='1' and ex.rs1/=REG_X0 then
            a := rf_a;
            if reg_we_wb='1' and rd_wb=ex.rs1 then a := data_wb; end if;
            if valid_me='1' and regwrite_me='1' and memread_me='0' and
               rd_me/=REG_X0 and rd_me=ex.rs1 then a := result_me; end if;
        end if;
        if ex.use_rs2='1' and ex.rs2/=REG_X0 then
            b := rf_b;
            if reg_we_wb='1' and rd_wb=ex.rs2 then b := data_wb; end if;
            if valid_me='1' and regwrite_me='1' and memread_me='0' and
               rd_me/=REG_X0 and rd_me=ex.rs2 then b := result_me; end if;
        end if;
        source_a <= a; source_b <= b;
    end process;

    alu_a <= source_a;
    alu_b <= ex.imm when ex.src2_imm='1' else source_b;
    u_alu : entity work.riscv_alu
        port map (i_arith=>ex.arith, i_sign=>ex.sign_ext, i_opcode=>ex.aluop,
                  i_shamt=>alu_b(SHAMT_WIDTH-1 downto 0),
                  i_src1=>alu_a, i_src2=>alu_b, o_res=>alu_result);

    eswp_in <= ex.imm when ex.eswp_imm='1' else source_a;
    u_eswp : entity work.riscv_eswp
        port map (i_data=>eswp_in, o_res=>eswp_result);

    result_ex <= std_logic_vector(unsigned(ex.pc) + to_unsigned(4, XLEN))
                    when ex.jump='1' else
                 eswp_result when ex.eswp='1' else alu_result;

    -- JALR impose le bit 0 de la cible a zero.
    target_pc <= (std_logic_vector(unsigned(source_a) + unsigned(ex.imm))
                  and JUMP_MASK) when ex.jump_reg='1' else
                 std_logic_vector(unsigned(ex.pc) + unsigned(ex.imm));
    redirect <= '1' when ex.valid='1' and
        (ex.jump='1' or (ex.branch_eq='1' and source_a=source_b)) else '0';

    ---------------------------------------------------------------------------
    -- EX/ME et ME/WB avancent meme pendant un stall ou un flush des jeunes.
    ---------------------------------------------------------------------------
    p_back_pipeline : process(i_clk, i_rstn)
    begin
        if i_rstn='0' then
            valid_me <= '0'; regwrite_me <= '0';
            memread_me <= '0'; memwrite_me <= '0';
            rd_me <= REG_X0; result_me <= ZERO; store_me <= ZERO;
            valid_wb <= '0'; regwrite_wb <= '0'; memread_wb <= '0';
            rd_wb <= REG_X0; result_wb <= ZERO;
        elsif rising_edge(i_clk) then
            valid_me <= ex.valid; regwrite_me <= ex.regwrite;
            memread_me <= ex.memread; memwrite_me <= ex.memwrite;
            rd_me <= ex.rd; result_me <= result_ex; store_me <= source_b;
            valid_wb <= valid_me; regwrite_wb <= regwrite_me;
            memread_wb <= memread_me; rd_wb <= rd_me; result_wb <= result_me;
        end if;
    end process;

    ---------------------------------------------------------------------------
    -- ME : adresses en octets, commandes actives uniquement pour LW/SW valides.
    ---------------------------------------------------------------------------
    o_dmem_en <= i_rstn and valid_me and (memread_me or memwrite_me);
    o_dmem_we <= i_rstn and valid_me and memwrite_me;
    o_dmem_addr <= result_me(8 downto 0);
    o_dmem_write <= store_me;

    ---------------------------------------------------------------------------
    -- WB : la lecture dpm et les commandes ME/WB ont la meme latence.
    ---------------------------------------------------------------------------
    data_wb <= i_dmem_read when memread_wb='1' else result_wb;
    reg_we_wb <= '1' when i_rstn='1' and valid_wb='1' and
                         regwrite_wb='1' and rd_wb/=REG_X0 else '0';
    o_tdo <= '0';
end architecture beh;
