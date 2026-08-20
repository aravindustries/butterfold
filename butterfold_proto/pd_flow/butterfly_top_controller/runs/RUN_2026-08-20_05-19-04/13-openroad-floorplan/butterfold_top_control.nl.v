module butterfold_top_control (clk,
    core_din_ready_i,
    core_din_valid_o,
    core_dout_valid_i,
    core_ofdm_active,
    core_result_ready_o,
    core_rx_complete,
    core_rx_selected_complete,
    core_tx_complete,
    debug_mode_o,
    debug_ready_i,
    debug_req_o,
    debug_rvalid_i,
    debug_write_o,
    din_ready_o,
    din_valid_i,
    dout_valid_o,
    drain_active,
    external_fire,
    feeder_start,
    job_push,
    rst_n,
    serializer_job_done_i,
    serializer_ready_i,
    serializer_valid_i,
    standalone_active_o,
    core_dout_i,
    debug_addr_o,
    debug_rdata_i,
    debug_wdata_o,
    din,
    dout,
    ext_state,
    job_head_command,
    serializer_dout_i,
    top_state_o);
 input clk;
 input core_din_ready_i;
 output core_din_valid_o;
 input core_dout_valid_i;
 output core_ofdm_active;
 output core_result_ready_o;
 output core_rx_complete;
 output core_rx_selected_complete;
 output core_tx_complete;
 output debug_mode_o;
 input debug_ready_i;
 output debug_req_o;
 input debug_rvalid_i;
 output debug_write_o;
 output din_ready_o;
 input din_valid_i;
 output dout_valid_o;
 output drain_active;
 output external_fire;
 output feeder_start;
 output job_push;
 input rst_n;
 input serializer_job_done_i;
 input serializer_ready_i;
 input serializer_valid_i;
 output standalone_active_o;
 input [7:0] core_dout_i;
 output [7:0] debug_addr_o;
 input [15:0] debug_rdata_i;
 output [15:0] debug_wdata_o;
 input [7:0] din;
 output [7:0] dout;
 output [2:0] ext_state;
 output [7:0] job_head_command;
 input [7:0] serializer_dout_i;
 output [4:0] top_state_o;

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
 wire _105_;
 wire _106_;
 wire _107_;
 wire _108_;
 wire _109_;
 wire _110_;
 wire _111_;
 wire _112_;
 wire _113_;
 wire _114_;
 wire _115_;
 wire _116_;
 wire _117_;
 wire _118_;
 wire _119_;
 wire _120_;
 wire _121_;
 wire _122_;
 wire _123_;
 wire _124_;
 wire _125_;
 wire _126_;
 wire _127_;
 wire _128_;
 wire _129_;
 wire _130_;
 wire _131_;
 wire _132_;
 wire _133_;
 wire _134_;
 wire _135_;
 wire _136_;
 wire _137_;
 wire _138_;
 wire _139_;
 wire _140_;
 wire _141_;
 wire _142_;
 wire _143_;
 wire _144_;
 wire _145_;
 wire _146_;
 wire _147_;
 wire _148_;
 wire _149_;
 wire _150_;
 wire _151_;
 wire _152_;
 wire _153_;
 wire _154_;
 wire _155_;
 wire _156_;
 wire _157_;
 wire _158_;
 wire _159_;
 wire _160_;
 wire _161_;
 wire _162_;
 wire _163_;
 wire _164_;
 wire _165_;
 wire _166_;
 wire _167_;
 wire _168_;
 wire _169_;
 wire _170_;
 wire _171_;
 wire _172_;
 wire _173_;
 wire _174_;
 wire _175_;
 wire _176_;
 wire _177_;
 wire _178_;
 wire _179_;
 wire _180_;
 wire _181_;
 wire _182_;
 wire _183_;
 wire _184_;
 wire _185_;
 wire _186_;
 wire _187_;
 wire _188_;
 wire _189_;
 wire _190_;
 wire _191_;
 wire _192_;
 wire _193_;
 wire _194_;
 wire _195_;
 wire _196_;
 wire _197_;
 wire _198_;
 wire _199_;
 wire _200_;
 wire _201_;
 wire _202_;
 wire _203_;
 wire _204_;
 wire _205_;
 wire _206_;
 wire _207_;
 wire _208_;
 wire _209_;
 wire _210_;
 wire _211_;
 wire _212_;
 wire _213_;
 wire _214_;
 wire _215_;
 wire _216_;
 wire _217_;
 wire _218_;
 wire _219_;
 wire _220_;
 wire _221_;
 wire _222_;
 wire _223_;
 wire _224_;
 wire _225_;
 wire _226_;
 wire _227_;
 wire _228_;
 wire _229_;
 wire _230_;
 wire _231_;
 wire _232_;
 wire _233_;
 wire _234_;
 wire _235_;
 wire _236_;
 wire _237_;
 wire _238_;
 wire _239_;
 wire _240_;
 wire _241_;
 wire _242_;
 wire _243_;
 wire _244_;
 wire _245_;
 wire _246_;
 wire _247_;
 wire _248_;
 wire _249_;
 wire _250_;
 wire _251_;
 wire _252_;
 wire _253_;
 wire _254_;
 wire _255_;
 wire _256_;
 wire _257_;
 wire _258_;
 wire _259_;
 wire _260_;
 wire _261_;
 wire _262_;
 wire _263_;
 wire _264_;
 wire _265_;
 wire _266_;
 wire _267_;
 wire _268_;
 wire _269_;
 wire _270_;
 wire _271_;
 wire _272_;
 wire _273_;
 wire _274_;
 wire _275_;
 wire _276_;
 wire _277_;
 wire _278_;
 wire _279_;
 wire _280_;
 wire _281_;
 wire _282_;
 wire _283_;
 wire _284_;
 wire _285_;
 wire _286_;
 wire _287_;
 wire _288_;
 wire _289_;
 wire _290_;
 wire _291_;
 wire _292_;
 wire _293_;
 wire _294_;
 wire _295_;
 wire _296_;
 wire _297_;
 wire _298_;
 wire _299_;
 wire _300_;
 wire _301_;
 wire _302_;
 wire _303_;
 wire _304_;
 wire _305_;
 wire _306_;
 wire _307_;
 wire _308_;
 wire _309_;
 wire _310_;
 wire _311_;
 wire _312_;
 wire _313_;
 wire _314_;
 wire _315_;
 wire _316_;
 wire _317_;
 wire _318_;
 wire _319_;
 wire _320_;
 wire _321_;
 wire _322_;
 wire _323_;
 wire _324_;
 wire _325_;
 wire _326_;
 wire _327_;
 wire _328_;
 wire _329_;
 wire _330_;
 wire _331_;
 wire _332_;
 wire _333_;
 wire _334_;
 wire _335_;
 wire _336_;
 wire _337_;
 wire _338_;
 wire _339_;
 wire _340_;
 wire _341_;
 wire _342_;
 wire _343_;
 wire _344_;
 wire _345_;
 wire _346_;
 wire _347_;
 wire _348_;
 wire _349_;
 wire _350_;
 wire _351_;
 wire _352_;
 wire _353_;
 wire _354_;
 wire _355_;
 wire _356_;
 wire _357_;
 wire _358_;
 wire _359_;
 wire _360_;
 wire _361_;
 wire _362_;
 wire _363_;
 wire _364_;
 wire _365_;
 wire _366_;
 wire _367_;
 wire _368_;
 wire _369_;
 wire _370_;
 wire _371_;
 wire _372_;
 wire _373_;
 wire \debug_data_hi[0] ;
 wire \debug_data_hi[1] ;
 wire \debug_data_hi[2] ;
 wire \debug_data_hi[3] ;
 wire \debug_data_hi[4] ;
 wire \debug_data_hi[5] ;
 wire \debug_data_hi[6] ;
 wire \debug_data_hi[7] ;
 wire \debug_read_latch[0] ;
 wire \debug_read_latch[10] ;
 wire \debug_read_latch[11] ;
 wire \debug_read_latch[12] ;
 wire \debug_read_latch[13] ;
 wire \debug_read_latch[14] ;
 wire \debug_read_latch[15] ;
 wire \debug_read_latch[1] ;
 wire \debug_read_latch[2] ;
 wire \debug_read_latch[3] ;
 wire \debug_read_latch[4] ;
 wire \debug_read_latch[5] ;
 wire \debug_read_latch[6] ;
 wire \debug_read_latch[7] ;
 wire \debug_read_latch[8] ;
 wire \debug_read_latch[9] ;
 wire \echo_data[0] ;
 wire \echo_data[1] ;
 wire \echo_data[2] ;
 wire \echo_data[3] ;
 wire \echo_data[4] ;
 wire \echo_data[5] ;
 wire \echo_data[6] ;
 wire \echo_data[7] ;
 wire \input_left[0] ;
 wire \input_left[1] ;
 wire \input_left[2] ;
 wire \input_left[3] ;
 wire \input_left[4] ;
 wire \input_left[5] ;
 wire \input_left[6] ;
 wire \input_left[7] ;
 wire \input_left[8] ;
 wire \magic_index[0] ;
 wire \magic_index[1] ;
 wire \magic_index[2] ;
 wire \output_left[0] ;
 wire \output_left[1] ;
 wire \output_left[2] ;
 wire \output_left[3] ;
 wire \output_left[4] ;
 wire \output_left[5] ;
 wire \output_left[6] ;
 wire \output_left[7] ;
 wire \output_left[8] ;

 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _374_ (.I(core_dout_valid_i),
    .ZN(_095_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _375_ (.I(\output_left[0] ),
    .ZN(_096_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _376_ (.I(\output_left[7] ),
    .ZN(_097_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _377_ (.I(\output_left[5] ),
    .ZN(_098_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _378_ (.I(job_head_command[6]),
    .ZN(_099_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _379_ (.I(top_state_o[1]),
    .ZN(_100_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _380_ (.I(top_state_o[2]),
    .ZN(_101_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _381_ (.I(top_state_o[3]),
    .ZN(_102_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _382_ (.I(\input_left[0] ),
    .ZN(_103_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _383_ (.I(\input_left[1] ),
    .ZN(_104_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _384_ (.I(\input_left[3] ),
    .ZN(_105_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _385_ (.I(\input_left[5] ),
    .ZN(_106_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _386_ (.I(\input_left[4] ),
    .ZN(_107_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _387_ (.I(top_state_o[4]),
    .ZN(_108_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _388_ (.I(din[1]),
    .ZN(_109_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _389_ (.I(din[3]),
    .ZN(_110_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _390_ (.I(din[6]),
    .ZN(_111_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _391_ (.I(din[0]),
    .ZN(_112_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _392_ (.I(din[7]),
    .ZN(_113_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _393_ (.I(\magic_index[0] ),
    .ZN(_114_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _394_ (.I(\magic_index[2] ),
    .ZN(_115_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _395_ (.I(debug_rvalid_i),
    .ZN(_116_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _396_ (.I(serializer_ready_i),
    .ZN(_117_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _397_ (.I(serializer_dout_i[0]),
    .ZN(_118_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _398_ (.I(core_dout_i[1]),
    .ZN(_119_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _399_ (.I(core_dout_i[3]),
    .ZN(_120_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _400_ (.I(serializer_dout_i[4]),
    .ZN(_121_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _401_ (.I(core_dout_i[6]),
    .ZN(_122_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _402_ (.A1(_099_),
    .A2(job_head_command[7]),
    .A3(job_head_command[5]),
    .A4(job_head_command[4]),
    .ZN(_123_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _403_ (.A1(job_head_command[3]),
    .A2(job_head_command[4]),
    .ZN(_124_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _404_ (.A1(job_head_command[1]),
    .A2(job_head_command[2]),
    .ZN(_125_));
 gf180mcu_fd_sc_mcu7t5v0__and4_1 _405_ (.A1(job_head_command[1]),
    .A2(job_head_command[2]),
    .A3(_123_),
    .A4(_124_),
    .Z(_126_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _406_ (.A1(\output_left[6] ),
    .A2(\output_left[7] ),
    .A3(\output_left[5] ),
    .A4(\output_left[4] ),
    .ZN(_127_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _407_ (.A1(\output_left[2] ),
    .A2(\output_left[3] ),
    .A3(\output_left[8] ),
    .ZN(_128_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _408_ (.A1(core_ofdm_active),
    .A2(core_dout_valid_i),
    .ZN(_129_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _409_ (.A1(\output_left[1] ),
    .A2(_096_),
    .A3(_129_),
    .ZN(_130_));
 gf180mcu_fd_sc_mcu7t5v0__and3_1 _410_ (.A1(_127_),
    .A2(_128_),
    .A3(_130_),
    .Z(_131_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _411_ (.A1(top_state_o[2]),
    .A2(top_state_o[3]),
    .ZN(_132_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _412_ (.A1(top_state_o[2]),
    .A2(top_state_o[3]),
    .Z(_133_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _413_ (.A1(top_state_o[0]),
    .A2(top_state_o[4]),
    .ZN(_134_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _414_ (.A1(top_state_o[0]),
    .A2(top_state_o[4]),
    .Z(_135_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _415_ (.A1(_100_),
    .A2(_135_),
    .ZN(_136_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _416_ (.A1(top_state_o[1]),
    .A2(_134_),
    .ZN(_137_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _417_ (.A1(_100_),
    .A2(_133_),
    .A3(_135_),
    .ZN(_138_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _418_ (.A1(_132_),
    .A2(_136_),
    .ZN(_139_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _419_ (.A1(_131_),
    .A2(_138_),
    .ZN(_140_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _420_ (.A1(_126_),
    .A2(_140_),
    .ZN(_001_));
 gf180mcu_fd_sc_mcu7t5v0__and3_1 _421_ (.A1(_126_),
    .A2(_131_),
    .A3(_138_),
    .Z(_000_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _422_ (.A1(top_state_o[0]),
    .A2(_100_),
    .A3(_108_),
    .ZN(_141_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _423_ (.A1(_133_),
    .A2(_141_),
    .ZN(_142_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _424_ (.A1(_133_),
    .A2(_141_),
    .Z(_143_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _425_ (.A1(_132_),
    .A2(_134_),
    .ZN(_144_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _426_ (.A1(top_state_o[0]),
    .A2(top_state_o[1]),
    .A3(top_state_o[4]),
    .ZN(_145_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _427_ (.A1(top_state_o[1]),
    .A2(_144_),
    .ZN(_146_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _428_ (.I(_146_),
    .ZN(ext_state[0]));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _429_ (.A1(top_state_o[1]),
    .A2(top_state_o[2]),
    .A3(top_state_o[3]),
    .A4(top_state_o[4]),
    .ZN(_147_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _430_ (.I(_147_),
    .ZN(ext_state[1]));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _431_ (.A1(top_state_o[2]),
    .A2(top_state_o[3]),
    .ZN(_148_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _432_ (.A1(top_state_o[3]),
    .A2(_145_),
    .ZN(_149_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _433_ (.A1(_100_),
    .A2(top_state_o[2]),
    .A3(top_state_o[3]),
    .A4(_108_),
    .ZN(_150_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _434_ (.A1(top_state_o[1]),
    .A2(top_state_o[4]),
    .A3(_148_),
    .ZN(_151_));
 gf180mcu_fd_sc_mcu7t5v0__and3_1 _435_ (.A1(top_state_o[0]),
    .A2(top_state_o[1]),
    .A3(_108_),
    .Z(_152_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _436_ (.A1(top_state_o[0]),
    .A2(top_state_o[1]),
    .A3(_108_),
    .ZN(_153_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _437_ (.A1(_101_),
    .A2(top_state_o[3]),
    .ZN(_154_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _438_ (.A1(_101_),
    .A2(top_state_o[3]),
    .A3(_152_),
    .ZN(_155_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _439_ (.A1(top_state_o[2]),
    .A2(_102_),
    .ZN(_156_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _440_ (.I(_156_),
    .ZN(_157_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _441_ (.A1(top_state_o[2]),
    .A2(_136_),
    .ZN(_158_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _442_ (.A1(_100_),
    .A2(_101_),
    .A3(top_state_o[3]),
    .A4(_135_),
    .ZN(_159_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _443_ (.A1(top_state_o[1]),
    .A2(top_state_o[2]),
    .A3(_102_),
    .A4(_134_),
    .ZN(_160_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _444_ (.A1(_155_),
    .A2(_160_),
    .ZN(_161_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _445_ (.A1(_150_),
    .A2(_155_),
    .ZN(_162_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _446_ (.A1(_101_),
    .A2(_152_),
    .B(_159_),
    .C(_151_),
    .ZN(_163_));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _447_ (.A1(top_state_o[2]),
    .A2(_153_),
    .B(_160_),
    .C(_150_),
    .ZN(_164_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _448_ (.A1(core_din_ready_i),
    .A2(_147_),
    .ZN(_165_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _449_ (.I(_165_),
    .ZN(_166_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _450_ (.A1(_163_),
    .A2(_165_),
    .ZN(din_ready_o));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _451_ (.A1(_164_),
    .A2(_166_),
    .B(din_valid_i),
    .ZN(_167_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _452_ (.I(_167_),
    .ZN(external_fire));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _453_ (.A1(\input_left[6] ),
    .A2(\input_left[7] ),
    .A3(\input_left[5] ),
    .A4(\input_left[4] ),
    .ZN(_168_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _454_ (.A1(\input_left[2] ),
    .A2(\input_left[3] ),
    .A3(\input_left[8] ),
    .ZN(_169_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _455_ (.A1(\input_left[0] ),
    .A2(_104_),
    .A3(_168_),
    .A4(_169_),
    .ZN(_170_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _456_ (.A1(_124_),
    .A2(_125_),
    .ZN(_171_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _457_ (.A1(job_head_command[1]),
    .A2(job_head_command[2]),
    .B(job_head_command[3]),
    .ZN(_172_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _458_ (.A1(_123_),
    .A2(_142_),
    .A3(_171_),
    .A4(_172_),
    .ZN(_173_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _459_ (.A1(_167_),
    .A2(_170_),
    .A3(_173_),
    .ZN(_002_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _460_ (.A1(top_state_o[1]),
    .A2(_135_),
    .A3(_156_),
    .ZN(_174_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _461_ (.A1(_137_),
    .A2(_154_),
    .ZN(_175_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _462_ (.A1(_148_),
    .A2(_153_),
    .ZN(_176_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _463_ (.A1(_141_),
    .A2(_154_),
    .ZN(_177_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _464_ (.A1(serializer_valid_i),
    .A2(_177_),
    .ZN(_178_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _465_ (.A1(_141_),
    .A2(_156_),
    .ZN(_179_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _466_ (.A1(_141_),
    .A2(_156_),
    .Z(_180_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _467_ (.A1(_174_),
    .A2(_175_),
    .A3(_179_),
    .ZN(_181_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _468_ (.A1(core_dout_valid_i),
    .A2(_176_),
    .ZN(_182_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _469_ (.A1(_178_),
    .A2(_181_),
    .A3(_182_),
    .ZN(dout_valid_o));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _470_ (.A1(_137_),
    .A2(_148_),
    .ZN(debug_write_o));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _471_ (.A1(din[4]),
    .A2(din[5]),
    .ZN(_183_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _472_ (.A1(din[4]),
    .A2(din[5]),
    .Z(_184_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _473_ (.A1(din[6]),
    .A2(_113_),
    .A3(_183_),
    .ZN(_185_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _474_ (.A1(din[3]),
    .A2(_111_),
    .A3(din[7]),
    .A4(_184_),
    .ZN(_186_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _475_ (.A1(_110_),
    .A2(din[6]),
    .A3(_113_),
    .A4(_183_),
    .ZN(_187_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _476_ (.A1(din[2]),
    .A2(_110_),
    .ZN(_188_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _477_ (.A1(din[2]),
    .A2(_110_),
    .Z(_189_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _478_ (.A1(din[1]),
    .A2(_111_),
    .A3(din[7]),
    .A4(_184_),
    .ZN(_190_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _479_ (.A1(_188_),
    .A2(_190_),
    .ZN(_191_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _480_ (.A1(din[0]),
    .A2(_190_),
    .ZN(_192_));
 gf180mcu_fd_sc_mcu7t5v0__nor3_1 _481_ (.A1(din[1]),
    .A2(_185_),
    .A3(_189_),
    .ZN(_193_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _482_ (.A1(_188_),
    .A2(_190_),
    .B(_186_),
    .ZN(_194_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _483_ (.A1(din[1]),
    .A2(_185_),
    .A3(_189_),
    .B(_187_),
    .ZN(_195_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _484_ (.A1(_146_),
    .A2(_195_),
    .ZN(_196_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _485_ (.A1(_146_),
    .A2(_167_),
    .B1(_196_),
    .B2(_140_),
    .ZN(_197_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _486_ (.A1(din[1]),
    .A2(din[2]),
    .ZN(_198_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _487_ (.A1(din[1]),
    .A2(din[2]),
    .A3(_186_),
    .ZN(_199_));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _488_ (.A1(_139_),
    .A2(_199_),
    .Z(_200_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _489_ (.A1(\output_left[1] ),
    .A2(\output_left[0] ),
    .ZN(_201_));
 gf180mcu_fd_sc_mcu7t5v0__or4_1 _490_ (.A1(\output_left[1] ),
    .A2(\output_left[0] ),
    .A3(\output_left[2] ),
    .A4(\output_left[3] ),
    .Z(_202_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _491_ (.I(_202_),
    .ZN(_203_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _492_ (.A1(\output_left[4] ),
    .A2(_202_),
    .ZN(_204_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _493_ (.A1(\output_left[4] ),
    .A2(_202_),
    .ZN(_205_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _494_ (.A1(_139_),
    .A2(_205_),
    .ZN(_206_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _495_ (.A1(_191_),
    .A2(_200_),
    .B1(_204_),
    .B2(_206_),
    .ZN(_207_));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _496_ (.A1(_197_),
    .A2(_207_),
    .Z(feeder_start));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _497_ (.A1(core_ofdm_active),
    .A2(_138_),
    .Z(drain_active));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _498_ (.A1(ext_state[0]),
    .A2(_194_),
    .B(_143_),
    .ZN(_208_));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _499_ (.A1(din_valid_i),
    .A2(_208_),
    .Z(core_din_valid_o));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _500_ (.A1(_152_),
    .A2(_157_),
    .ZN(_209_));
 gf180mcu_fd_sc_mcu7t5v0__oai22_1 _501_ (.A1(_137_),
    .A2(_148_),
    .B1(_153_),
    .B2(_156_),
    .ZN(debug_req_o));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _502_ (.I(debug_req_o),
    .ZN(_210_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _503_ (.A1(top_state_o[2]),
    .A2(_149_),
    .ZN(_211_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _504_ (.A1(debug_req_o),
    .A2(_211_),
    .Z(debug_mode_o));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _505_ (.A1(standalone_active_o),
    .A2(_117_),
    .ZN(core_result_ready_o));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _506_ (.A1(\debug_read_latch[0] ),
    .A2(_175_),
    .B1(_177_),
    .B2(\debug_read_latch[8] ),
    .C1(\echo_data[0] ),
    .C2(_174_),
    .ZN(_212_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _507_ (.A1(core_dout_valid_i),
    .A2(_212_),
    .ZN(_213_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _508_ (.A1(core_dout_valid_i),
    .A2(core_dout_i[0]),
    .B(_213_),
    .C(serializer_valid_i),
    .ZN(_214_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _509_ (.A1(serializer_valid_i),
    .A2(_118_),
    .B(_214_),
    .ZN(dout[0]));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _510_ (.A1(\magic_index[1] ),
    .A2(\magic_index[2] ),
    .ZN(_215_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _511_ (.A1(\debug_read_latch[1] ),
    .A2(_175_),
    .B1(_179_),
    .B2(_215_),
    .ZN(_216_));
 gf180mcu_fd_sc_mcu7t5v0__aoi221_1 _512_ (.A1(\echo_data[1] ),
    .A2(_174_),
    .B1(_177_),
    .B2(\debug_read_latch[9] ),
    .C(core_dout_valid_i),
    .ZN(_217_));
 gf180mcu_fd_sc_mcu7t5v0__aoi221_1 _513_ (.A1(core_dout_valid_i),
    .A2(_119_),
    .B1(_216_),
    .B2(_217_),
    .C(serializer_valid_i),
    .ZN(_218_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _514_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[1]),
    .B(_218_),
    .ZN(_219_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _515_ (.I(_219_),
    .ZN(dout[1]));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _516_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[2]),
    .ZN(_220_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _517_ (.A1(_114_),
    .A2(_215_),
    .ZN(_221_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _518_ (.A1(\debug_read_latch[10] ),
    .A2(_177_),
    .ZN(_222_));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _519_ (.A1(\echo_data[2] ),
    .A2(_174_),
    .B1(_179_),
    .B2(_221_),
    .C1(_175_),
    .C2(\debug_read_latch[2] ),
    .ZN(_223_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _520_ (.A1(_182_),
    .A2(_222_),
    .A3(_223_),
    .ZN(_224_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _521_ (.A1(_095_),
    .A2(core_dout_i[2]),
    .B(_224_),
    .ZN(_225_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _522_ (.A1(serializer_valid_i),
    .A2(_225_),
    .B(_220_),
    .ZN(dout[2]));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _523_ (.A1(_114_),
    .A2(\magic_index[1] ),
    .A3(_115_),
    .A4(_179_),
    .ZN(_226_));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _524_ (.A1(\debug_read_latch[3] ),
    .A2(_175_),
    .B1(_177_),
    .B2(\debug_read_latch[11] ),
    .C1(\echo_data[3] ),
    .C2(_174_),
    .ZN(_227_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _525_ (.A1(_182_),
    .A2(_226_),
    .A3(_227_),
    .ZN(_228_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _526_ (.A1(core_dout_valid_i),
    .A2(_120_),
    .B(serializer_valid_i),
    .ZN(_229_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _527_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[3]),
    .B1(_228_),
    .B2(_229_),
    .ZN(_230_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _528_ (.I(_230_),
    .ZN(dout[3]));
 gf180mcu_fd_sc_mcu7t5v0__aoi222_1 _529_ (.A1(\debug_read_latch[4] ),
    .A2(_175_),
    .B1(_177_),
    .B2(\debug_read_latch[12] ),
    .C1(\echo_data[4] ),
    .C2(_174_),
    .ZN(_231_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _530_ (.A1(core_dout_valid_i),
    .A2(_231_),
    .ZN(_232_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _531_ (.A1(core_dout_valid_i),
    .A2(core_dout_i[4]),
    .B(_232_),
    .C(serializer_valid_i),
    .ZN(_233_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _532_ (.A1(serializer_valid_i),
    .A2(_121_),
    .B(_233_),
    .ZN(dout[4]));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _533_ (.A1(\debug_read_latch[5] ),
    .A2(_175_),
    .ZN(_234_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _534_ (.A1(\echo_data[5] ),
    .A2(_174_),
    .B1(_177_),
    .B2(\debug_read_latch[13] ),
    .ZN(_235_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _535_ (.A1(_182_),
    .A2(_234_),
    .A3(_235_),
    .ZN(_236_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _536_ (.A1(_095_),
    .A2(core_dout_i[5]),
    .B(_236_),
    .ZN(_237_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _537_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[5]),
    .ZN(_238_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _538_ (.A1(serializer_valid_i),
    .A2(_237_),
    .B(_238_),
    .ZN(dout[5]));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _539_ (.A1(\debug_read_latch[6] ),
    .A2(_175_),
    .B1(_177_),
    .B2(\debug_read_latch[14] ),
    .ZN(_239_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _540_ (.A1(\echo_data[6] ),
    .A2(_174_),
    .B(_179_),
    .C(core_dout_valid_i),
    .ZN(_240_));
 gf180mcu_fd_sc_mcu7t5v0__aoi221_1 _541_ (.A1(core_dout_valid_i),
    .A2(_122_),
    .B1(_239_),
    .B2(_240_),
    .C(serializer_valid_i),
    .ZN(_241_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _542_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[6]),
    .B(_241_),
    .ZN(_242_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _543_ (.I(_242_),
    .ZN(dout[6]));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _544_ (.A1(\debug_read_latch[15] ),
    .A2(_177_),
    .ZN(_243_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _545_ (.A1(\echo_data[7] ),
    .A2(_174_),
    .B1(_175_),
    .B2(\debug_read_latch[7] ),
    .ZN(_244_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _546_ (.A1(_182_),
    .A2(_243_),
    .A3(_244_),
    .ZN(_245_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _547_ (.A1(_095_),
    .A2(core_dout_i[7]),
    .B(_245_),
    .ZN(_246_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _548_ (.A1(serializer_valid_i),
    .A2(serializer_dout_i[7]),
    .ZN(_247_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _549_ (.A1(serializer_valid_i),
    .A2(_246_),
    .B(_247_),
    .ZN(dout[7]));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _550_ (.A1(debug_rvalid_i),
    .A2(_211_),
    .ZN(_248_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _551_ (.I0(debug_rdata_i[2]),
    .I1(\debug_read_latch[2] ),
    .S(_248_),
    .Z(_003_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _552_ (.I0(debug_rdata_i[3]),
    .I1(\debug_read_latch[3] ),
    .S(_248_),
    .Z(_004_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _553_ (.I0(debug_rdata_i[4]),
    .I1(\debug_read_latch[4] ),
    .S(_248_),
    .Z(_005_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _554_ (.I0(debug_rdata_i[5]),
    .I1(\debug_read_latch[5] ),
    .S(_248_),
    .Z(_006_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _555_ (.I0(debug_rdata_i[6]),
    .I1(\debug_read_latch[6] ),
    .S(_248_),
    .Z(_007_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _556_ (.I0(debug_rdata_i[7]),
    .I1(\debug_read_latch[7] ),
    .S(_248_),
    .Z(_008_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _557_ (.I0(debug_rdata_i[8]),
    .I1(\debug_read_latch[8] ),
    .S(_248_),
    .Z(_009_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _558_ (.I0(debug_rdata_i[9]),
    .I1(\debug_read_latch[9] ),
    .S(_248_),
    .Z(_010_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _559_ (.I0(debug_rdata_i[10]),
    .I1(\debug_read_latch[10] ),
    .S(_248_),
    .Z(_011_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _560_ (.I0(debug_rdata_i[11]),
    .I1(\debug_read_latch[11] ),
    .S(_248_),
    .Z(_012_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _561_ (.I0(debug_rdata_i[12]),
    .I1(\debug_read_latch[12] ),
    .S(_248_),
    .Z(_013_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _562_ (.I0(debug_rdata_i[13]),
    .I1(\debug_read_latch[13] ),
    .S(_248_),
    .Z(_014_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _563_ (.I0(debug_rdata_i[14]),
    .I1(\debug_read_latch[14] ),
    .S(_248_),
    .Z(_015_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _564_ (.I0(debug_rdata_i[15]),
    .I1(\debug_read_latch[15] ),
    .S(_248_),
    .Z(_016_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _565_ (.A1(top_state_o[2]),
    .A2(top_state_o[3]),
    .A3(_145_),
    .A4(external_fire),
    .ZN(_249_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _566_ (.A1(\debug_data_hi[0] ),
    .A2(_249_),
    .ZN(_250_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _567_ (.A1(_112_),
    .A2(_249_),
    .B(_250_),
    .ZN(_017_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _568_ (.A1(\debug_data_hi[1] ),
    .A2(_249_),
    .ZN(_251_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _569_ (.A1(_109_),
    .A2(_249_),
    .B(_251_),
    .ZN(_018_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _570_ (.I0(din[2]),
    .I1(\debug_data_hi[2] ),
    .S(_249_),
    .Z(_019_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _571_ (.A1(\debug_data_hi[3] ),
    .A2(_249_),
    .ZN(_252_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _572_ (.A1(_110_),
    .A2(_249_),
    .B(_252_),
    .ZN(_020_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _573_ (.I0(din[4]),
    .I1(\debug_data_hi[4] ),
    .S(_249_),
    .Z(_021_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _574_ (.I0(din[5]),
    .I1(\debug_data_hi[5] ),
    .S(_249_),
    .Z(_022_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _575_ (.A1(\debug_data_hi[6] ),
    .A2(_249_),
    .ZN(_253_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _576_ (.A1(_111_),
    .A2(_249_),
    .B(_253_),
    .ZN(_023_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _577_ (.A1(\debug_data_hi[7] ),
    .A2(_249_),
    .ZN(_254_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _578_ (.A1(_113_),
    .A2(_249_),
    .B(_254_),
    .ZN(_024_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _579_ (.A1(din_valid_i),
    .A2(_132_),
    .A3(_152_),
    .ZN(_255_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _580_ (.A1(\echo_data[0] ),
    .A2(_255_),
    .ZN(_256_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _581_ (.A1(_112_),
    .A2(_255_),
    .B(_256_),
    .ZN(_025_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _582_ (.A1(\echo_data[1] ),
    .A2(_255_),
    .ZN(_257_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _583_ (.A1(_109_),
    .A2(_255_),
    .B(_257_),
    .ZN(_026_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _584_ (.I0(din[2]),
    .I1(\echo_data[2] ),
    .S(_255_),
    .Z(_027_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _585_ (.A1(\echo_data[3] ),
    .A2(_255_),
    .ZN(_258_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _586_ (.A1(_110_),
    .A2(_255_),
    .B(_258_),
    .ZN(_028_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _587_ (.I0(din[4]),
    .I1(\echo_data[4] ),
    .S(_255_),
    .Z(_029_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _588_ (.I0(din[5]),
    .I1(\echo_data[5] ),
    .S(_255_),
    .Z(_030_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _589_ (.A1(\echo_data[6] ),
    .A2(_255_),
    .ZN(_259_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _590_ (.A1(_111_),
    .A2(_255_),
    .B(_259_),
    .ZN(_031_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _591_ (.A1(\echo_data[7] ),
    .A2(_255_),
    .ZN(_260_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _592_ (.A1(_113_),
    .A2(_255_),
    .B(_260_),
    .ZN(_032_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _593_ (.A1(_109_),
    .A2(_112_),
    .A3(_185_),
    .A4(_189_),
    .ZN(_261_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _594_ (.A1(\magic_index[0] ),
    .A2(\magic_index[1] ),
    .ZN(_262_));
 gf180mcu_fd_sc_mcu7t5v0__oai32_1 _595_ (.A1(\magic_index[2] ),
    .A2(_180_),
    .A3(_262_),
    .B1(_261_),
    .B2(ext_state[0]),
    .ZN(_263_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _596_ (.I0(_180_),
    .I1(_195_),
    .S(_146_),
    .Z(_264_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _597_ (.A1(_146_),
    .A2(_167_),
    .B(_263_),
    .C(_264_),
    .ZN(_265_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _598_ (.A1(top_state_o[0]),
    .A2(_265_),
    .B(\magic_index[0] ),
    .ZN(_266_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _599_ (.A1(\magic_index[0] ),
    .A2(_265_),
    .B(_266_),
    .ZN(_033_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _600_ (.A1(_179_),
    .A2(_262_),
    .ZN(_267_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _601_ (.A1(\magic_index[0] ),
    .A2(_265_),
    .B(\magic_index[1] ),
    .ZN(_268_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _602_ (.A1(_265_),
    .A2(_267_),
    .B(_268_),
    .ZN(_034_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _603_ (.A1(_265_),
    .A2(_267_),
    .B(_115_),
    .ZN(_035_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _604_ (.A1(serializer_job_done_i),
    .A2(standalone_active_o),
    .ZN(_269_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _605_ (.A1(_138_),
    .A2(_269_),
    .ZN(_270_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _606_ (.A1(_138_),
    .A2(_269_),
    .B(_144_),
    .ZN(_271_));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _607_ (.A1(ext_state[0]),
    .A2(external_fire),
    .B(_264_),
    .C(_271_),
    .ZN(_272_));
 gf180mcu_fd_sc_mcu7t5v0__aoi211_1 _608_ (.A1(din[1]),
    .A2(din[2]),
    .B(_138_),
    .C(_187_),
    .ZN(_273_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _609_ (.I0(_273_),
    .I1(standalone_active_o),
    .S(_272_),
    .Z(_036_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _610_ (.A1(din_valid_i),
    .A2(_161_),
    .ZN(_274_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _611_ (.A1(debug_addr_o[0]),
    .A2(_274_),
    .ZN(_275_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _612_ (.A1(_112_),
    .A2(_274_),
    .B(_275_),
    .ZN(_037_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _613_ (.A1(debug_addr_o[1]),
    .A2(_274_),
    .ZN(_276_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _614_ (.A1(_109_),
    .A2(_274_),
    .B(_276_),
    .ZN(_038_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _615_ (.I0(din[2]),
    .I1(debug_addr_o[2]),
    .S(_274_),
    .Z(_039_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _616_ (.A1(debug_addr_o[3]),
    .A2(_274_),
    .ZN(_277_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _617_ (.A1(_110_),
    .A2(_274_),
    .B(_277_),
    .ZN(_040_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _618_ (.I0(din[4]),
    .I1(debug_addr_o[4]),
    .S(_274_),
    .Z(_041_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _619_ (.I0(din[5]),
    .I1(debug_addr_o[5]),
    .S(_274_),
    .Z(_042_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _620_ (.A1(debug_addr_o[6]),
    .A2(_274_),
    .ZN(_278_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _621_ (.A1(_111_),
    .A2(_274_),
    .B(_278_),
    .ZN(_043_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _622_ (.A1(debug_addr_o[7]),
    .A2(_274_),
    .ZN(_279_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _623_ (.A1(_113_),
    .A2(_274_),
    .B(_279_),
    .ZN(_044_));
 gf180mcu_fd_sc_mcu7t5v0__or3_1 _624_ (.A1(_141_),
    .A2(_148_),
    .A3(_167_),
    .Z(_280_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _625_ (.A1(debug_wdata_o[0]),
    .A2(_280_),
    .ZN(_281_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _626_ (.A1(_112_),
    .A2(_280_),
    .B(_281_),
    .ZN(_045_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _627_ (.A1(debug_wdata_o[1]),
    .A2(_280_),
    .ZN(_282_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _628_ (.A1(_109_),
    .A2(_280_),
    .B(_282_),
    .ZN(_046_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _629_ (.I0(din[2]),
    .I1(debug_wdata_o[2]),
    .S(_280_),
    .Z(_047_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _630_ (.A1(debug_wdata_o[3]),
    .A2(_280_),
    .ZN(_283_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _631_ (.A1(_110_),
    .A2(_280_),
    .B(_283_),
    .ZN(_048_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _632_ (.I0(din[4]),
    .I1(debug_wdata_o[4]),
    .S(_280_),
    .Z(_049_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _633_ (.I0(din[5]),
    .I1(debug_wdata_o[5]),
    .S(_280_),
    .Z(_050_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _634_ (.A1(debug_wdata_o[6]),
    .A2(_280_),
    .ZN(_284_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _635_ (.A1(_111_),
    .A2(_280_),
    .B(_284_),
    .ZN(_051_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _636_ (.A1(debug_wdata_o[7]),
    .A2(_280_),
    .ZN(_285_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _637_ (.A1(_113_),
    .A2(_280_),
    .B(_285_),
    .ZN(_052_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _638_ (.I0(\debug_data_hi[0] ),
    .I1(debug_wdata_o[8]),
    .S(_280_),
    .Z(_053_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _639_ (.I0(\debug_data_hi[1] ),
    .I1(debug_wdata_o[9]),
    .S(_280_),
    .Z(_054_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _640_ (.I0(\debug_data_hi[2] ),
    .I1(debug_wdata_o[10]),
    .S(_280_),
    .Z(_055_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _641_ (.I0(\debug_data_hi[3] ),
    .I1(debug_wdata_o[11]),
    .S(_280_),
    .Z(_056_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _642_ (.I0(\debug_data_hi[4] ),
    .I1(debug_wdata_o[12]),
    .S(_280_),
    .Z(_057_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _643_ (.I0(\debug_data_hi[5] ),
    .I1(debug_wdata_o[13]),
    .S(_280_),
    .Z(_058_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _644_ (.I0(\debug_data_hi[6] ),
    .I1(debug_wdata_o[14]),
    .S(_280_),
    .Z(_059_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _645_ (.I0(\debug_data_hi[7] ),
    .I1(debug_wdata_o[15]),
    .S(_280_),
    .Z(_060_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _646_ (.A1(_147_),
    .A2(_164_),
    .ZN(_286_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _647_ (.A1(_142_),
    .A2(_170_),
    .B1(_211_),
    .B2(_116_),
    .ZN(_287_));
 gf180mcu_fd_sc_mcu7t5v0__oai221_1 _648_ (.A1(debug_ready_i),
    .A2(_210_),
    .B1(_286_),
    .B2(external_fire),
    .C(_287_),
    .ZN(_288_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _649_ (.A1(top_state_o[0]),
    .A2(_265_),
    .B(_288_),
    .ZN(_289_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _650_ (.A1(din[2]),
    .A2(din[3]),
    .ZN(_290_));
 gf180mcu_fd_sc_mcu7t5v0__oai32_1 _651_ (.A1(_109_),
    .A2(_185_),
    .A3(_189_),
    .B1(_192_),
    .B2(_290_),
    .ZN(_291_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _652_ (.A1(_146_),
    .A2(_291_),
    .ZN(_292_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _653_ (.A1(_149_),
    .A2(_158_),
    .A3(_196_),
    .A4(_292_),
    .ZN(_293_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _654_ (.I0(top_state_o[0]),
    .I1(_293_),
    .S(_289_),
    .Z(_061_));
 gf180mcu_fd_sc_mcu7t5v0__oai221_1 _655_ (.A1(_141_),
    .A2(_157_),
    .B1(_270_),
    .B2(_131_),
    .C(_158_),
    .ZN(_294_));
 gf180mcu_fd_sc_mcu7t5v0__clkinv_1 _656_ (.I(_294_),
    .ZN(_295_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _657_ (.A1(din[1]),
    .A2(din[0]),
    .A3(_185_),
    .A4(_290_),
    .ZN(_296_));
 gf180mcu_fd_sc_mcu7t5v0__oai221_1 _658_ (.A1(_109_),
    .A2(_112_),
    .B1(_291_),
    .B2(_296_),
    .C(_146_),
    .ZN(_297_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _659_ (.A1(_295_),
    .A2(_297_),
    .ZN(_298_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _660_ (.I0(top_state_o[1]),
    .I1(_298_),
    .S(_289_),
    .Z(_062_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _661_ (.A1(top_state_o[0]),
    .A2(top_state_o[1]),
    .A3(_132_),
    .ZN(_299_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _662_ (.A1(_261_),
    .A2(_296_),
    .B(_146_),
    .ZN(_300_));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _663_ (.A1(_100_),
    .A2(_102_),
    .B(_108_),
    .C(_101_),
    .ZN(_301_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _664_ (.A1(_299_),
    .A2(_300_),
    .B1(_301_),
    .B2(_209_),
    .ZN(_302_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _665_ (.A1(_150_),
    .A2(_155_),
    .A3(_158_),
    .ZN(_303_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _666_ (.A1(_302_),
    .A2(_303_),
    .Z(_304_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _667_ (.I0(top_state_o[2]),
    .I1(_304_),
    .S(_289_),
    .Z(_063_));
 gf180mcu_fd_sc_mcu7t5v0__nor4_1 _668_ (.A1(_162_),
    .A2(_177_),
    .A3(debug_req_o),
    .A4(_211_),
    .ZN(_305_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _669_ (.A1(ext_state[0]),
    .A2(_192_),
    .A3(_290_),
    .B(_305_),
    .ZN(_306_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _670_ (.I0(top_state_o[3]),
    .I1(_306_),
    .S(_289_),
    .Z(_064_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _671_ (.I0(core_ofdm_active),
    .I1(_207_),
    .S(_197_),
    .Z(_066_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _672_ (.A1(_146_),
    .A2(external_fire),
    .ZN(_307_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _673_ (.A1(job_head_command[0]),
    .A2(_307_),
    .ZN(_308_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _674_ (.A1(_112_),
    .A2(_307_),
    .B(_308_),
    .ZN(_067_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _675_ (.A1(job_head_command[1]),
    .A2(_307_),
    .ZN(_309_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _676_ (.A1(_109_),
    .A2(_307_),
    .B(_309_),
    .ZN(_068_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _677_ (.I0(din[2]),
    .I1(job_head_command[2]),
    .S(_307_),
    .Z(_069_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _678_ (.A1(job_head_command[3]),
    .A2(_307_),
    .ZN(_310_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _679_ (.A1(_110_),
    .A2(_307_),
    .B(_310_),
    .ZN(_070_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _680_ (.I0(din[4]),
    .I1(job_head_command[4]),
    .S(_307_),
    .Z(_071_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _681_ (.I0(din[5]),
    .I1(job_head_command[5]),
    .S(_307_),
    .Z(_072_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _682_ (.A1(job_head_command[6]),
    .A2(_307_),
    .ZN(_311_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _683_ (.A1(_111_),
    .A2(_307_),
    .B(_311_),
    .ZN(_073_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _684_ (.A1(job_head_command[7]),
    .A2(_307_),
    .ZN(_312_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _685_ (.A1(_113_),
    .A2(_307_),
    .B(_312_),
    .ZN(_074_));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _686_ (.A1(external_fire),
    .A2(_208_),
    .Z(_313_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _687_ (.A1(external_fire),
    .A2(_208_),
    .ZN(_314_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _688_ (.A1(top_state_o[0]),
    .A2(_103_),
    .B(_314_),
    .ZN(_315_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _689_ (.A1(_103_),
    .A2(_314_),
    .B(_315_),
    .ZN(_075_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _690_ (.A1(\input_left[0] ),
    .A2(\input_left[1] ),
    .Z(_316_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _691_ (.A1(din[2]),
    .A2(_112_),
    .A3(_143_),
    .A4(_186_),
    .ZN(_317_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _692_ (.A1(_143_),
    .A2(_316_),
    .B(_317_),
    .ZN(_318_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _693_ (.A1(_313_),
    .A2(_318_),
    .ZN(_319_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _694_ (.A1(_104_),
    .A2(_313_),
    .B(_319_),
    .ZN(_076_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _695_ (.A1(_109_),
    .A2(din[0]),
    .Z(_320_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _696_ (.A1(_142_),
    .A2(_187_),
    .ZN(_321_));
 gf180mcu_fd_sc_mcu7t5v0__or3_1 _697_ (.A1(\input_left[0] ),
    .A2(\input_left[1] ),
    .A3(\input_left[2] ),
    .Z(_322_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _698_ (.A1(\input_left[0] ),
    .A2(\input_left[1] ),
    .B(\input_left[2] ),
    .ZN(_323_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _699_ (.A1(_322_),
    .A2(_323_),
    .ZN(_324_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _700_ (.A1(_320_),
    .A2(_321_),
    .B1(_324_),
    .B2(_142_),
    .ZN(_325_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _701_ (.A1(\input_left[2] ),
    .A2(_314_),
    .ZN(_326_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _702_ (.A1(_314_),
    .A2(_325_),
    .B(_326_),
    .ZN(_077_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _703_ (.A1(_109_),
    .A2(din[2]),
    .A3(din[0]),
    .A4(_186_),
    .ZN(_327_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _704_ (.A1(_143_),
    .A2(_191_),
    .A3(_327_),
    .ZN(_328_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _705_ (.A1(_322_),
    .A2(_328_),
    .B(_314_),
    .ZN(_329_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _706_ (.A1(\input_left[3] ),
    .A2(_322_),
    .ZN(_330_));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _707_ (.A1(_143_),
    .A2(_330_),
    .B(_328_),
    .C(_313_),
    .ZN(_331_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _708_ (.A1(_105_),
    .A2(_329_),
    .B(_331_),
    .ZN(_078_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _709_ (.A1(_107_),
    .A2(_330_),
    .ZN(_332_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _710_ (.A1(_142_),
    .A2(_332_),
    .ZN(_333_));
 gf180mcu_fd_sc_mcu7t5v0__and2_1 _711_ (.A1(_313_),
    .A2(_333_),
    .Z(_334_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _712_ (.A1(_313_),
    .A2(_333_),
    .ZN(_335_));
 gf180mcu_fd_sc_mcu7t5v0__nand4_1 _713_ (.A1(_143_),
    .A2(_191_),
    .A3(_199_),
    .A4(_327_),
    .ZN(_336_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _714_ (.A1(\input_left[3] ),
    .A2(_322_),
    .A3(_333_),
    .B(_336_),
    .ZN(_337_));
 gf180mcu_fd_sc_mcu7t5v0__aoi22_1 _715_ (.A1(_107_),
    .A2(_335_),
    .B1(_337_),
    .B2(_313_),
    .ZN(_079_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _716_ (.A1(\input_left[5] ),
    .A2(_332_),
    .ZN(_338_));
 gf180mcu_fd_sc_mcu7t5v0__nand3_1 _717_ (.A1(external_fire),
    .A2(_208_),
    .A3(_338_),
    .ZN(_339_));
 gf180mcu_fd_sc_mcu7t5v0__oai22_1 _718_ (.A1(_106_),
    .A2(_334_),
    .B1(_339_),
    .B2(_143_),
    .ZN(_080_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _719_ (.A1(_142_),
    .A2(_314_),
    .ZN(_340_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _720_ (.A1(\input_left[6] ),
    .A2(_339_),
    .Z(_341_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _721_ (.A1(_340_),
    .A2(_341_),
    .ZN(_081_));
 gf180mcu_fd_sc_mcu7t5v0__or3_1 _722_ (.A1(\input_left[6] ),
    .A2(\input_left[7] ),
    .A3(_339_),
    .Z(_342_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _723_ (.A1(\input_left[6] ),
    .A2(_339_),
    .B(\input_left[7] ),
    .ZN(_343_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _724_ (.A1(_342_),
    .A2(_343_),
    .B(_340_),
    .ZN(_082_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _725_ (.A1(\input_left[8] ),
    .A2(_313_),
    .ZN(_344_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _726_ (.A1(din[2]),
    .A2(_320_),
    .B(_198_),
    .ZN(_345_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _727_ (.A1(_168_),
    .A2(_330_),
    .ZN(_346_));
 gf180mcu_fd_sc_mcu7t5v0__xnor2_1 _728_ (.A1(\input_left[8] ),
    .A2(_346_),
    .ZN(_347_));
 gf180mcu_fd_sc_mcu7t5v0__aoi221_1 _729_ (.A1(_321_),
    .A2(_345_),
    .B1(_347_),
    .B2(_142_),
    .C(_314_),
    .ZN(_348_));
 gf180mcu_fd_sc_mcu7t5v0__nor2_1 _730_ (.A1(_344_),
    .A2(_348_),
    .ZN(_083_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _731_ (.A1(top_state_o[1]),
    .A2(_129_),
    .B(_144_),
    .ZN(_349_));
 gf180mcu_fd_sc_mcu7t5v0__oai211_1 _732_ (.A1(ext_state[0]),
    .A2(external_fire),
    .B(_264_),
    .C(_349_),
    .ZN(_350_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _733_ (.A1(_096_),
    .A2(top_state_o[1]),
    .B(_350_),
    .ZN(_351_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _734_ (.A1(_096_),
    .A2(_350_),
    .B(_351_),
    .ZN(_084_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _735_ (.A1(din[0]),
    .A2(_191_),
    .B(_139_),
    .ZN(_352_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _736_ (.A1(\output_left[1] ),
    .A2(_096_),
    .Z(_353_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _737_ (.A1(_139_),
    .A2(_353_),
    .B(_352_),
    .ZN(_354_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _738_ (.A1(\output_left[1] ),
    .A2(_350_),
    .ZN(_355_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _739_ (.A1(_350_),
    .A2(_354_),
    .B(_355_),
    .ZN(_085_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _740_ (.A1(\output_left[2] ),
    .A2(_201_),
    .Z(_356_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _741_ (.A1(_189_),
    .A2(_192_),
    .B(_139_),
    .ZN(_357_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _742_ (.A1(_139_),
    .A2(_356_),
    .B(_357_),
    .ZN(_358_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _743_ (.A1(\output_left[2] ),
    .A2(_350_),
    .ZN(_359_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _744_ (.A1(_350_),
    .A2(_358_),
    .B(_359_),
    .ZN(_086_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _745_ (.A1(\output_left[1] ),
    .A2(\output_left[0] ),
    .A3(\output_left[2] ),
    .B(\output_left[3] ),
    .ZN(_360_));
 gf180mcu_fd_sc_mcu7t5v0__and3_1 _746_ (.A1(_138_),
    .A2(_202_),
    .A3(_360_),
    .Z(_361_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _747_ (.A1(\output_left[3] ),
    .A2(_350_),
    .ZN(_362_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _748_ (.A1(_200_),
    .A2(_350_),
    .A3(_361_),
    .B(_362_),
    .ZN(_087_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _749_ (.I0(_207_),
    .I1(\output_left[4] ),
    .S(_350_),
    .Z(_088_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _750_ (.A1(_098_),
    .A2(_205_),
    .ZN(_363_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _751_ (.A1(_206_),
    .A2(_350_),
    .B(\output_left[5] ),
    .ZN(_364_));
 gf180mcu_fd_sc_mcu7t5v0__oai31_1 _752_ (.A1(_139_),
    .A2(_350_),
    .A3(_363_),
    .B(_364_),
    .ZN(_089_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _753_ (.A1(\output_left[6] ),
    .A2(_363_),
    .Z(_365_));
 gf180mcu_fd_sc_mcu7t5v0__or2_1 _754_ (.A1(_350_),
    .A2(_365_),
    .Z(_366_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _755_ (.A1(_350_),
    .A2(_363_),
    .B(\output_left[6] ),
    .ZN(_367_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _756_ (.A1(_366_),
    .A2(_367_),
    .B(_340_),
    .ZN(_090_));
 gf180mcu_fd_sc_mcu7t5v0__oai32_1 _757_ (.A1(_097_),
    .A2(_350_),
    .A3(_365_),
    .B1(_142_),
    .B2(_314_),
    .ZN(_368_));
 gf180mcu_fd_sc_mcu7t5v0__aoi21_1 _758_ (.A1(_097_),
    .A2(_366_),
    .B(_368_),
    .ZN(_091_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _759_ (.A1(_127_),
    .A2(_203_),
    .ZN(_369_));
 gf180mcu_fd_sc_mcu7t5v0__xor2_1 _760_ (.A1(\output_left[8] ),
    .A2(_369_),
    .Z(_370_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _761_ (.A1(_138_),
    .A2(_370_),
    .ZN(_371_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _762_ (.A1(_138_),
    .A2(_193_),
    .B(_371_),
    .ZN(_372_));
 gf180mcu_fd_sc_mcu7t5v0__nand2_1 _763_ (.A1(\output_left[8] ),
    .A2(_350_),
    .ZN(_373_));
 gf180mcu_fd_sc_mcu7t5v0__oai21_1 _764_ (.A1(_350_),
    .A2(_372_),
    .B(_373_),
    .ZN(_092_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _765_ (.I0(debug_rdata_i[0]),
    .I1(\debug_read_latch[0] ),
    .S(_248_),
    .Z(_093_));
 gf180mcu_fd_sc_mcu7t5v0__mux2_2 _766_ (.I0(debug_rdata_i[1]),
    .I1(\debug_read_latch[1] ),
    .S(_248_),
    .Z(_094_));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _767_ (.D(_036_),
    .RN(rst_n),
    .CLK(clk),
    .Q(standalone_active_o));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _768_ (.D(_037_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[0]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _769_ (.D(_038_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[1]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _770_ (.D(_039_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[2]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _771_ (.D(_040_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[3]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _772_ (.D(_041_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[4]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _773_ (.D(_042_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[5]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _774_ (.D(_043_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[6]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _775_ (.D(_044_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_addr_o[7]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _776_ (.D(_045_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[0]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _777_ (.D(_046_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[1]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _778_ (.D(_047_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[2]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _779_ (.D(_048_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[3]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _780_ (.D(_049_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[4]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _781_ (.D(_050_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[5]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _782_ (.D(_051_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[6]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _783_ (.D(_052_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[7]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _784_ (.D(_053_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[8]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _785_ (.D(_054_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[9]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _786_ (.D(_055_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[10]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _787_ (.D(_056_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[11]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _788_ (.D(_057_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[12]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _789_ (.D(_058_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[13]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _790_ (.D(_059_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[14]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _791_ (.D(_060_),
    .RN(rst_n),
    .CLK(clk),
    .Q(debug_wdata_o[15]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _792_ (.D(_061_),
    .RN(rst_n),
    .CLK(clk),
    .Q(top_state_o[0]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _793_ (.D(_062_),
    .RN(rst_n),
    .CLK(clk),
    .Q(top_state_o[1]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _794_ (.D(_063_),
    .RN(rst_n),
    .CLK(clk),
    .Q(top_state_o[2]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _795_ (.D(_064_),
    .RN(rst_n),
    .CLK(clk),
    .Q(top_state_o[3]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _796_ (.D(_065_),
    .RN(rst_n),
    .CLK(clk),
    .Q(top_state_o[4]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _797_ (.D(_066_),
    .RN(rst_n),
    .CLK(clk),
    .Q(core_ofdm_active));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _798_ (.D(_067_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[0]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _799_ (.D(_068_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[1]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _800_ (.D(_069_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[2]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _801_ (.D(_070_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[3]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _802_ (.D(_071_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[4]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _803_ (.D(_072_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[5]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _804_ (.D(_073_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[6]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _805_ (.D(_074_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_head_command[7]));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _806_ (.D(_075_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _807_ (.D(_076_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _808_ (.D(_077_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _809_ (.D(_078_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[3] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _810_ (.D(_079_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[4] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _811_ (.D(_080_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[5] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _812_ (.D(_081_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[6] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _813_ (.D(_082_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[7] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _814_ (.D(_083_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\input_left[8] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _815_ (.D(_084_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _816_ (.D(_085_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _817_ (.D(_086_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _818_ (.D(_087_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[3] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _819_ (.D(_088_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[4] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _820_ (.D(_089_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[5] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _821_ (.D(_090_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[6] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _822_ (.D(_091_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[7] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _823_ (.D(_092_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\output_left[8] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _824_ (.D(_093_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _825_ (.D(_094_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _826_ (.D(_003_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _827_ (.D(_004_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[3] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _828_ (.D(_005_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[4] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _829_ (.D(_006_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[5] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _830_ (.D(_007_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[6] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _831_ (.D(_008_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[7] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _832_ (.D(_009_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[8] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _833_ (.D(_010_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[9] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _834_ (.D(_011_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[10] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _835_ (.D(_012_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[11] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _836_ (.D(_013_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[12] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _837_ (.D(_014_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[13] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _838_ (.D(_015_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[14] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _839_ (.D(_016_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_read_latch[15] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _840_ (.D(_017_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _841_ (.D(_018_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _842_ (.D(_019_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _843_ (.D(_020_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[3] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _844_ (.D(_021_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[4] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _845_ (.D(_022_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[5] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _846_ (.D(_023_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[6] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _847_ (.D(_024_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\debug_data_hi[7] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _848_ (.D(_025_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _849_ (.D(_026_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _850_ (.D(_027_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _851_ (.D(_028_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[3] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _852_ (.D(_029_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[4] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _853_ (.D(_030_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[5] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _854_ (.D(_031_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[6] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _855_ (.D(_032_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\echo_data[7] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _856_ (.D(_033_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\magic_index[0] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _857_ (.D(_034_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\magic_index[1] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _858_ (.D(_035_),
    .RN(rst_n),
    .CLK(clk),
    .Q(\magic_index[2] ));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _859_ (.D(_002_),
    .RN(rst_n),
    .CLK(clk),
    .Q(job_push));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _860_ (.D(_000_),
    .RN(rst_n),
    .CLK(clk),
    .Q(core_rx_complete));
 gf180mcu_fd_sc_mcu7t5v0__dffrnq_1 _861_ (.D(_001_),
    .RN(rst_n),
    .CLK(clk),
    .Q(core_tx_complete));
 gf180mcu_fd_sc_mcu7t5v0__tiel _862_ (.ZN(ext_state[2]));
 gf180mcu_fd_sc_mcu7t5v0__tiel _863_ (.ZN(_065_));
 gf180mcu_fd_sc_mcu7t5v0__buf_1 _864_ (.I(core_rx_complete),
    .Z(core_rx_selected_complete));
endmodule
