# Core-to-ACH padring connectivity

**PASS**

| Logical port | Direction | ACH pin | Pad instance | Master | Data pin | Controls | Status |
|---|---|---|---|---|---|---|---|
| `clk` | INPUT | `clk` | `W08` | `gf180mcu_fd_io__in_s` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[0]` | INPUT | `din[0]` | `W18` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[1]` | INPUT | `din[1]` | `W17` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[2]` | INPUT | `din[2]` | `W16` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[3]` | INPUT | `din[3]` | `W15` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[4]` | INPUT | `din[4]` | `W14` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[5]` | INPUT | `din[5]` | `W13` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[6]` | INPUT | `din[6]` | `W12` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din[7]` | INPUT | `din[7]` | `W11` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `din_ready_o` | OUTPUT | `din_ready_o_OUT` | `W19` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `din_valid_i` | INPUT | `din_valid_i` | `W10` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |
| `dout[0]` | OUTPUT | `dout_OUT[0]` | `N06` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[1]` | OUTPUT | `dout_OUT[1]` | `N05` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[2]` | OUTPUT | `dout_OUT[2]` | `N04` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[3]` | OUTPUT | `dout_OUT[3]` | `N03` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[4]` | OUTPUT | `dout_OUT[4]` | `N02` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[5]` | OUTPUT | `dout_OUT[5]` | `N01` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[6]` | OUTPUT | `dout_OUT[6]` | `W22` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout[7]` | OUTPUT | `dout_OUT[7]` | `W21` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `dout_valid_o` | OUTPUT | `dout_valid_o_OUT` | `W20` | `gf180mcu_fd_io__bi_t` | `A` | `{'CS': 0, 'SL': 0, 'IE': 0, 'OE': 1, 'PU': 0, 'PD': 0, 'PDRV0': 0, 'PDRV1': 0}` | **PASS** |
| `rst_n` | INPUT | `rst_n` | `W09` | `gf180mcu_fd_io__in_c` | `Y` | `{'PU': 0, 'PD': 0}` | **PASS** |

Mapping is derived programmatically from `D03_ACH_interface.yaml`; programmable constants follow the documented GF180 application policy.
