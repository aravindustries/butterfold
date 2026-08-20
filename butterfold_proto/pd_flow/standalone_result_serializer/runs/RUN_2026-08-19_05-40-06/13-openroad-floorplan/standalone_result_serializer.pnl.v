module standalone_result_serializer (busy_o,
    clk,
    dout_valid_o,
    enable_i,
    job_done_o,
    result_last_i,
    result_ready_o,
    result_valid_i,
    rst_n,
    transaction_done_o,
    X0_i_i,
    X0_q_i,
    X1_i_i,
    X1_q_i,
    X2_i_i,
    X2_q_i,
    dout_o,
    result_addr0_i,
    result_addr1_i,
    result_addr2_i,
    result_radix_i);
 output busy_o;
 input clk;
 output dout_valid_o;
 input enable_i;
 output job_done_o;
 input result_last_i;
 output result_ready_o;
 input result_valid_i;
 input rst_n;
 output transaction_done_o;
 input [15:0] X0_i_i;
 input [15:0] X0_q_i;
 input [15:0] X1_i_i;
 input [15:0] X1_q_i;
 input [15:0] X2_i_i;
 input [15:0] X2_q_i;
 output [7:0] dout_o;
 input [6:0] result_addr0_i;
 input [6:0] result_addr1_i;
 input [6:0] result_addr2_i;
 input [1:0] result_radix_i;

 wire _000_;
 wire _001_;
 wire _002_;
 wire _003_;
 wire _004_;
 wire _005_;
 wire _006_;
 wire _007_;
 wire _008_;
 wire _009_;
 wire _010_;
 wire _011_;
 wire _012_;
 wire _013_;
 wire _014_;
 wire _015_;
 wire _016_;
 wire _017_;
 wire _018_;
 wire _019_;
 wire _020_;
 wire _021_;
 wire _022_;
 wire _023_;
 wire _024_;
 wire _025_;
 wire _026_;
 wire _027_;
 wire _028_;
 wire _029_;
 wire _030_;
 wire _031_;
 wire _032_;
 wire _033_;
 wire _034_;
 wire _035_;
 wire _036_;
 wire _037_;
 wire _038_;
 wire _039_;
 wire _040_;
 wire _041_;
 wire _042_;
 wire _043_;
 wire _044_;
 wire _045_;
 wire _046_;
 wire _047_;
 wire _048_;
 wire _049_;
 wire _050_;
 wire _051_;
 wire _052_;
 wire _053_;
 wire _054_;
 wire _055_;
 wire _056_;
 wire _057_;
 wire _058_;
 wire _059_;
 wire _060_;
 wire _061_;
 wire _062_;
 wire _063_;
 wire _064_;
 wire _065_;
 wire _066_;
 wire _067_;
 wire _068_;
 wire _069_;
 wire _070_;
 wire _071_;
 wire _072_;
 wire _073_;
 wire _074_;
 wire _075_;
 wire _076_;
 wire _077_;
 wire _078_;
 wire _079_;
 wire _080_;
 wire _081_;
 wire _082_;
 wire _083_;
 wire _084_;
 wire _085_;
 wire _086_;
 wire _087_;
 wire _088_;
 wire _089_;
 wire _090_;
 wire _091_;
 wire _092_;
 wire _093_;
 wire _094_;
 wire _095_;
 wire _096_;
 wire _097_;
 wire _098_;
 wire _099_;
 wire _100_;
 wire _101_;
 wire _102_;
 wire _103_;
 wire _104_;
 wire \byte_index[0] ;
 wire \byte_index[1] ;
 wire \byte_index[2] ;
 wire \byte_index[3] ;
 wire VDD;
 wire VSS;

 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _105_ (.I(\byte_index[0] ),
    .ZN(_007_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _106_ (.I(\byte_index[1] ),
    .ZN(_008_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _107_ (.I(\byte_index[3] ),
    .ZN(_009_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _108_ (.I(\byte_index[2] ),
    .ZN(_010_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _109_ (.I(busy_o),
    .ZN(_011_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _110_ (.A1(result_radix_i[0]),
    .A2(result_radix_i[1]),
    .B(\byte_index[1] ),
    .C(\byte_index[2] ),
    .ZN(_012_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _111_ (.A1(\byte_index[1] ),
    .A2(\byte_index[2] ),
    .A3(result_radix_i[0]),
    .A4(result_radix_i[1]),
    .Z(_013_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _112_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .Z(_014_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _113_ (.A1(_012_),
    .A2(_013_),
    .B(_014_),
    .C(\byte_index[3] ),
    .ZN(_015_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _114_ (.A1(_011_),
    .A2(_015_),
    .ZN(_002_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _115_ (.A1(enable_i),
    .A2(result_valid_i),
    .B(busy_o),
    .ZN(_016_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _116_ (.A1(_002_),
    .A2(_016_),
    .ZN(_000_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _117_ (.A1(enable_i),
    .A2(_002_),
    .Z(result_ready_o),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _118_ (.A1(result_last_i),
    .A2(_002_),
    .Z(_001_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _119_ (.A1(\byte_index[3] ),
    .A2(\byte_index[2] ),
    .ZN(_017_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _120_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .A3(_017_),
    .ZN(_018_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _121_ (.A1(_007_),
    .A2(\byte_index[1] ),
    .A3(\byte_index[3] ),
    .A4(_010_),
    .ZN(_019_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _122_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .A3(\byte_index[3] ),
    .A4(\byte_index[2] ),
    .ZN(_020_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _123_ (.A1(_007_),
    .A2(\byte_index[1] ),
    .A3(_009_),
    .A4(\byte_index[2] ),
    .ZN(_021_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _124_ (.A1(_007_),
    .A2(\byte_index[1] ),
    .A3(\byte_index[3] ),
    .A4(\byte_index[2] ),
    .ZN(_022_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _125_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .A3(\byte_index[3] ),
    .A4(_010_),
    .ZN(_023_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _126_ (.A1(X0_i_i[8]),
    .A2(_022_),
    .B1(_023_),
    .B2(X0_q_i[0]),
    .ZN(_024_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _127_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .ZN(_025_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _128_ (.A1(\byte_index[3] ),
    .A2(\byte_index[2] ),
    .A3(_025_),
    .ZN(_026_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _129_ (.A1(\byte_index[3] ),
    .A2(_010_),
    .A3(_025_),
    .ZN(_027_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _130_ (.A1(\byte_index[0] ),
    .A2(_008_),
    .A3(\byte_index[3] ),
    .A4(\byte_index[2] ),
    .ZN(_028_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _131_ (.A1(_007_),
    .A2(\byte_index[1] ),
    .A3(_017_),
    .ZN(_029_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _132_ (.A1(\byte_index[0] ),
    .A2(_008_),
    .A3(\byte_index[3] ),
    .A4(_010_),
    .ZN(_030_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _133_ (.A1(\byte_index[0] ),
    .A2(_008_),
    .A3(_009_),
    .A4(\byte_index[2] ),
    .ZN(_031_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _134_ (.A1(\byte_index[0] ),
    .A2(_008_),
    .A3(_017_),
    .ZN(_032_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _135_ (.A1(_009_),
    .A2(\byte_index[2] ),
    .A3(_025_),
    .ZN(_033_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _136_ (.A1(\byte_index[0] ),
    .A2(\byte_index[1] ),
    .A3(_009_),
    .A4(\byte_index[2] ),
    .ZN(_034_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _137_ (.A1(X2_q_i[8]),
    .A2(_029_),
    .B1(_033_),
    .B2(X2_i_i[8]),
    .ZN(_035_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _138_ (.A1(result_addr2_i[0]),
    .A2(_031_),
    .B1(_034_),
    .B2(X1_q_i[8]),
    .C1(_032_),
    .C2(X2_q_i[0]),
    .ZN(_036_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _139_ (.A1(X2_i_i[0]),
    .A2(_018_),
    .B1(_030_),
    .B2(X1_i_i[8]),
    .ZN(_037_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _140_ (.A1(result_addr1_i[0]),
    .A2(_019_),
    .B1(_026_),
    .B2(X0_q_i[8]),
    .ZN(_038_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _141_ (.A1(result_addr0_i[0]),
    .A2(_020_),
    .B1(_028_),
    .B2(X0_i_i[0]),
    .ZN(_039_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _142_ (.A1(X1_q_i[0]),
    .A2(_021_),
    .B1(_027_),
    .B2(X1_i_i[0]),
    .ZN(_040_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _143_ (.A1(_037_),
    .A2(_038_),
    .A3(_039_),
    .A4(_040_),
    .Z(_041_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _144_ (.A1(_024_),
    .A2(_035_),
    .A3(_036_),
    .A4(_041_),
    .ZN(dout_o[0]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _145_ (.A1(X0_i_i[9]),
    .A2(_022_),
    .B1(_026_),
    .B2(X0_q_i[9]),
    .ZN(_042_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _146_ (.A1(X2_q_i[9]),
    .A2(_029_),
    .B1(_032_),
    .B2(X2_q_i[1]),
    .ZN(_043_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _147_ (.A1(result_addr0_i[1]),
    .A2(_020_),
    .B1(_031_),
    .B2(result_addr2_i[1]),
    .C1(X2_i_i[9]),
    .C2(_033_),
    .ZN(_044_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _148_ (.A1(X2_i_i[1]),
    .A2(_018_),
    .B1(_023_),
    .B2(X0_q_i[1]),
    .ZN(_045_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _149_ (.A1(result_addr1_i[1]),
    .A2(_019_),
    .B1(_030_),
    .B2(X1_i_i[9]),
    .ZN(_046_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _150_ (.A1(X0_i_i[1]),
    .A2(_028_),
    .B1(_034_),
    .B2(X1_q_i[9]),
    .ZN(_047_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _151_ (.A1(X1_q_i[1]),
    .A2(_021_),
    .B1(_027_),
    .B2(X1_i_i[1]),
    .ZN(_048_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _152_ (.A1(_045_),
    .A2(_046_),
    .A3(_047_),
    .A4(_048_),
    .Z(_049_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _153_ (.A1(_042_),
    .A2(_043_),
    .A3(_044_),
    .A4(_049_),
    .ZN(dout_o[1]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _154_ (.A1(X0_i_i[2]),
    .A2(_028_),
    .B1(_030_),
    .B2(X1_i_i[10]),
    .ZN(_050_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _155_ (.A1(X1_i_i[2]),
    .A2(_027_),
    .B1(_034_),
    .B2(X1_q_i[10]),
    .ZN(_051_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _156_ (.A1(X1_q_i[2]),
    .A2(_021_),
    .B1(_022_),
    .B2(X0_i_i[10]),
    .C1(_031_),
    .C2(result_addr2_i[2]),
    .ZN(_052_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _157_ (.A1(X0_q_i[2]),
    .A2(_023_),
    .B1(_033_),
    .B2(X2_i_i[10]),
    .ZN(_053_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _158_ (.A1(result_addr1_i[2]),
    .A2(_019_),
    .B1(_026_),
    .B2(X0_q_i[10]),
    .ZN(_054_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _159_ (.A1(X2_i_i[2]),
    .A2(_018_),
    .B1(_020_),
    .B2(result_addr0_i[2]),
    .ZN(_055_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _160_ (.A1(X2_q_i[10]),
    .A2(_029_),
    .B1(_032_),
    .B2(X2_q_i[2]),
    .ZN(_056_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _161_ (.A1(_053_),
    .A2(_054_),
    .A3(_055_),
    .A4(_056_),
    .Z(_057_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _162_ (.A1(_050_),
    .A2(_051_),
    .A3(_052_),
    .A4(_057_),
    .ZN(dout_o[2]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _163_ (.A1(X1_i_i[3]),
    .A2(_027_),
    .B1(_031_),
    .B2(result_addr2_i[3]),
    .ZN(_058_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _164_ (.A1(X0_i_i[11]),
    .A2(_022_),
    .B1(_032_),
    .B2(X2_q_i[3]),
    .ZN(_059_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _165_ (.A1(X2_i_i[3]),
    .A2(_018_),
    .B1(_033_),
    .B2(X2_i_i[11]),
    .C1(_034_),
    .C2(X1_q_i[11]),
    .ZN(_060_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _166_ (.A1(X1_q_i[3]),
    .A2(_021_),
    .B1(_028_),
    .B2(X0_i_i[3]),
    .ZN(_061_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _167_ (.A1(result_addr1_i[3]),
    .A2(_019_),
    .B1(_030_),
    .B2(X1_i_i[11]),
    .ZN(_062_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _168_ (.A1(X0_q_i[3]),
    .A2(_023_),
    .B1(_026_),
    .B2(X0_q_i[11]),
    .ZN(_063_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _169_ (.A1(result_addr0_i[3]),
    .A2(_020_),
    .B1(_029_),
    .B2(X2_q_i[11]),
    .ZN(_064_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _170_ (.A1(_061_),
    .A2(_062_),
    .A3(_063_),
    .A4(_064_),
    .Z(_065_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _171_ (.A1(_058_),
    .A2(_059_),
    .A3(_060_),
    .A4(_065_),
    .ZN(dout_o[3]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _172_ (.A1(result_addr2_i[4]),
    .A2(_031_),
    .B1(_032_),
    .B2(X2_q_i[4]),
    .ZN(_066_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _173_ (.A1(X2_q_i[12]),
    .A2(_029_),
    .B1(_030_),
    .B2(X1_i_i[12]),
    .ZN(_067_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _174_ (.A1(X0_q_i[4]),
    .A2(_023_),
    .B1(_026_),
    .B2(X0_q_i[12]),
    .C1(_033_),
    .C2(X2_i_i[12]),
    .ZN(_068_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _175_ (.A1(X2_i_i[4]),
    .A2(_018_),
    .B1(_019_),
    .B2(result_addr1_i[4]),
    .ZN(_069_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _176_ (.A1(result_addr0_i[4]),
    .A2(_020_),
    .B1(_022_),
    .B2(X0_i_i[12]),
    .ZN(_070_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _177_ (.A1(X0_i_i[4]),
    .A2(_028_),
    .B1(_034_),
    .B2(X1_q_i[12]),
    .ZN(_071_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _178_ (.A1(X1_q_i[4]),
    .A2(_021_),
    .B1(_027_),
    .B2(X1_i_i[4]),
    .ZN(_072_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _179_ (.A1(_069_),
    .A2(_070_),
    .A3(_071_),
    .A4(_072_),
    .Z(_073_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _180_ (.A1(_066_),
    .A2(_067_),
    .A3(_068_),
    .A4(_073_),
    .ZN(dout_o[4]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _181_ (.A1(X0_i_i[13]),
    .A2(_022_),
    .B1(_033_),
    .B2(X2_i_i[13]),
    .ZN(_074_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _182_ (.A1(X2_q_i[13]),
    .A2(_029_),
    .B1(_032_),
    .B2(X2_q_i[5]),
    .ZN(_075_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _183_ (.A1(X2_i_i[5]),
    .A2(_018_),
    .B1(_023_),
    .B2(X0_q_i[5]),
    .C1(_026_),
    .C2(X0_q_i[13]),
    .ZN(_076_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _184_ (.A1(result_addr1_i[5]),
    .A2(_019_),
    .B1(_021_),
    .B2(X1_q_i[5]),
    .ZN(_077_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _185_ (.A1(result_addr0_i[5]),
    .A2(_020_),
    .B1(_030_),
    .B2(X1_i_i[13]),
    .ZN(_078_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _186_ (.A1(X1_i_i[5]),
    .A2(_027_),
    .B1(_028_),
    .B2(X0_i_i[5]),
    .ZN(_079_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _187_ (.A1(result_addr2_i[5]),
    .A2(_031_),
    .B1(_034_),
    .B2(X1_q_i[13]),
    .ZN(_080_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _188_ (.A1(_077_),
    .A2(_078_),
    .A3(_079_),
    .A4(_080_),
    .Z(_081_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _189_ (.A1(_074_),
    .A2(_075_),
    .A3(_076_),
    .A4(_081_),
    .ZN(dout_o[5]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _190_ (.A1(result_addr1_i[6]),
    .A2(_019_),
    .B1(_030_),
    .B2(X1_i_i[14]),
    .ZN(_082_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _191_ (.A1(X0_i_i[14]),
    .A2(_022_),
    .B1(_032_),
    .B2(X2_q_i[6]),
    .ZN(_083_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _192_ (.A1(X2_i_i[6]),
    .A2(_018_),
    .B1(_033_),
    .B2(X2_i_i[14]),
    .C1(_034_),
    .C2(X1_q_i[14]),
    .ZN(_084_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _193_ (.A1(X1_q_i[6]),
    .A2(_021_),
    .B1(_028_),
    .B2(X0_i_i[6]),
    .ZN(_085_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _194_ (.A1(X1_i_i[6]),
    .A2(_027_),
    .B1(_031_),
    .B2(result_addr2_i[6]),
    .ZN(_086_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _195_ (.A1(X0_q_i[6]),
    .A2(_023_),
    .B1(_026_),
    .B2(X0_q_i[14]),
    .ZN(_087_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _196_ (.A1(result_addr0_i[6]),
    .A2(_020_),
    .B1(_029_),
    .B2(X2_q_i[14]),
    .ZN(_088_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _197_ (.A1(_085_),
    .A2(_086_),
    .A3(_087_),
    .A4(_088_),
    .Z(_089_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _198_ (.A1(_082_),
    .A2(_083_),
    .A3(_084_),
    .A4(_089_),
    .ZN(dout_o[6]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _199_ (.A1(X2_i_i[7]),
    .A2(_018_),
    .B1(_021_),
    .B2(X1_q_i[7]),
    .ZN(_090_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _200_ (.A1(X0_q_i[15]),
    .A2(_026_),
    .B1(_033_),
    .B2(X2_i_i[15]),
    .ZN(_091_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _201_ (.A1(X0_q_i[7]),
    .A2(_023_),
    .B1(_028_),
    .B2(X0_i_i[7]),
    .ZN(_092_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _202_ (.A1(X0_i_i[15]),
    .A2(_022_),
    .B1(_027_),
    .B2(X1_i_i[7]),
    .ZN(_093_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _203_ (.A1(X2_q_i[15]),
    .A2(_029_),
    .B1(_032_),
    .B2(X2_q_i[7]),
    .ZN(_094_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _204_ (.A1(_090_),
    .A2(_091_),
    .A3(_093_),
    .A4(_094_),
    .Z(_095_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _205_ (.A1(X1_i_i[15]),
    .A2(_030_),
    .B1(_034_),
    .B2(X1_q_i[15]),
    .ZN(_096_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _206_ (.A1(_092_),
    .A2(_095_),
    .A3(_096_),
    .ZN(dout_o[7]),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _207_ (.A1(_007_),
    .A2(_016_),
    .ZN(_097_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _208_ (.A1(busy_o),
    .A2(_015_),
    .ZN(_098_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _209_ (.A1(_007_),
    .A2(_098_),
    .B(_097_),
    .ZN(_003_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _210_ (.A1(\byte_index[1] ),
    .A2(_016_),
    .ZN(_099_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _211_ (.A1(busy_o),
    .A2(_014_),
    .A3(_015_),
    .ZN(_100_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _212_ (.A1(_099_),
    .A2(_100_),
    .ZN(_004_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _213_ (.A1(busy_o),
    .A2(_015_),
    .B(_016_),
    .ZN(_101_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _214_ (.A1(_007_),
    .A2(_008_),
    .A3(_010_),
    .A4(_016_),
    .ZN(_102_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _215_ (.A1(\byte_index[1] ),
    .A2(_097_),
    .ZN(_103_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _216_ (.A1(_010_),
    .A2(_103_),
    .B(_102_),
    .C(_101_),
    .ZN(_005_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _217_ (.A1(_009_),
    .A2(_102_),
    .Z(_104_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _218_ (.A1(_101_),
    .A2(_104_),
    .ZN(_006_),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _219_ (.D(_003_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\byte_index[0] ),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _220_ (.D(_004_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\byte_index[1] ),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _221_ (.D(_005_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\byte_index[2] ),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _222_ (.D(_006_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\byte_index[3] ),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _223_ (.D(_000_),
    .RN(rst_n),
    .CLK(clk),
    .Q(busy_o),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _224_ (.D(_002_),
    .RN(rst_n),
    .CLK(clk),
    .Q(transaction_done_o),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _225_ (.D(_001_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_done_o),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
 gf180mcu_fd_sc_mcu7t5v0__buf_1 _226_ (.I(busy_o),
    .Z(dout_valid_o),
    .VDD(VDD),
    .VNW(VDD),
    .VPW(VSS),
    .VSS(VSS));
endmodule
