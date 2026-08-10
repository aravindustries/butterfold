`timescale 1ns/1ps
`default_nettype none

// Hard-coded 64-entry forward W128 twiddle ROM. No SRAM macro is used.
module fft128_twiddle_rom (
    input  logic [5:0] addr_i,
    output logic signed [7:0] re_o,
    output logic signed [7:0] im_o
);
    always @* begin
        case (addr_i)
            6'd0: begin re_o = 8'sh7f; im_o = 8'sh00; end
            6'd1: begin re_o = 8'sh7f; im_o = 8'shfa; end
            6'd2: begin re_o = 8'sh7f; im_o = 8'shf3; end
            6'd3: begin re_o = 8'sh7f; im_o = 8'shed; end
            6'd4: begin re_o = 8'sh7e; im_o = 8'she7; end
            6'd5: begin re_o = 8'sh7c; im_o = 8'she1; end
            6'd6: begin re_o = 8'sh7a; im_o = 8'shdb; end
            6'd7: begin re_o = 8'sh79; im_o = 8'shd5; end
            6'd8: begin re_o = 8'sh76; im_o = 8'shcf; end
            6'd9: begin re_o = 8'sh74; im_o = 8'shc9; end
            6'd10: begin re_o = 8'sh71; im_o = 8'shc4; end
            6'd11: begin re_o = 8'sh6e; im_o = 8'shbe; end
            6'd12: begin re_o = 8'sh6a; im_o = 8'shb9; end
            6'd13: begin re_o = 8'sh67; im_o = 8'shb4; end
            6'd14: begin re_o = 8'sh63; im_o = 8'shaf; end
            6'd15: begin re_o = 8'sh5f; im_o = 8'shaa; end
            6'd16: begin re_o = 8'sh5b; im_o = 8'sha5; end
            6'd17: begin re_o = 8'sh56; im_o = 8'sha1; end
            6'd18: begin re_o = 8'sh51; im_o = 8'sh9d; end
            6'd19: begin re_o = 8'sh4c; im_o = 8'sh99; end
            6'd20: begin re_o = 8'sh47; im_o = 8'sh96; end
            6'd21: begin re_o = 8'sh42; im_o = 8'sh92; end
            6'd22: begin re_o = 8'sh3c; im_o = 8'sh8f; end
            6'd23: begin re_o = 8'sh37; im_o = 8'sh8c; end
            6'd24: begin re_o = 8'sh31; im_o = 8'sh8a; end
            6'd25: begin re_o = 8'sh2b; im_o = 8'sh87; end
            6'd26: begin re_o = 8'sh25; im_o = 8'sh86; end
            6'd27: begin re_o = 8'sh1f; im_o = 8'sh84; end
            6'd28: begin re_o = 8'sh19; im_o = 8'sh82; end
            6'd29: begin re_o = 8'sh13; im_o = 8'sh81; end
            6'd30: begin re_o = 8'sh0d; im_o = 8'sh81; end
            6'd31: begin re_o = 8'sh06; im_o = 8'sh80; end
            6'd32: begin re_o = 8'sh00; im_o = 8'sh80; end
            6'd33: begin re_o = 8'shfa; im_o = 8'sh80; end
            6'd34: begin re_o = 8'shf3; im_o = 8'sh81; end
            6'd35: begin re_o = 8'shed; im_o = 8'sh81; end
            6'd36: begin re_o = 8'she7; im_o = 8'sh82; end
            6'd37: begin re_o = 8'she1; im_o = 8'sh84; end
            6'd38: begin re_o = 8'shdb; im_o = 8'sh86; end
            6'd39: begin re_o = 8'shd5; im_o = 8'sh87; end
            6'd40: begin re_o = 8'shcf; im_o = 8'sh8a; end
            6'd41: begin re_o = 8'shc9; im_o = 8'sh8c; end
            6'd42: begin re_o = 8'shc4; im_o = 8'sh8f; end
            6'd43: begin re_o = 8'shbe; im_o = 8'sh92; end
            6'd44: begin re_o = 8'shb9; im_o = 8'sh96; end
            6'd45: begin re_o = 8'shb4; im_o = 8'sh99; end
            6'd46: begin re_o = 8'shaf; im_o = 8'sh9d; end
            6'd47: begin re_o = 8'shaa; im_o = 8'sha1; end
            6'd48: begin re_o = 8'sha5; im_o = 8'sha5; end
            6'd49: begin re_o = 8'sha1; im_o = 8'shaa; end
            6'd50: begin re_o = 8'sh9d; im_o = 8'shaf; end
            6'd51: begin re_o = 8'sh99; im_o = 8'shb4; end
            6'd52: begin re_o = 8'sh96; im_o = 8'shb9; end
            6'd53: begin re_o = 8'sh92; im_o = 8'shbe; end
            6'd54: begin re_o = 8'sh8f; im_o = 8'shc4; end
            6'd55: begin re_o = 8'sh8c; im_o = 8'shc9; end
            6'd56: begin re_o = 8'sh8a; im_o = 8'shcf; end
            6'd57: begin re_o = 8'sh87; im_o = 8'shd5; end
            6'd58: begin re_o = 8'sh86; im_o = 8'shdb; end
            6'd59: begin re_o = 8'sh84; im_o = 8'she1; end
            6'd60: begin re_o = 8'sh82; im_o = 8'she7; end
            6'd61: begin re_o = 8'sh81; im_o = 8'shed; end
            6'd62: begin re_o = 8'sh81; im_o = 8'shf3; end
            6'd63: begin re_o = 8'sh80; im_o = 8'shfa; end
            default: begin re_o = 8'sd0; im_o = 8'sd0; end
        endcase
    end
endmodule

`default_nettype wire
