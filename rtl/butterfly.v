module butterfly(
    input signed [15:0] top_re,
    input signed [15:0] top_im,
    input signed [15:0] bot_re,
    input signed [15:0] bot_im,
    input signed [7:0]  w_re,
    input signed [7:0]  w_im,
    output signed [15:0] otop_re,
    output signed [15:0] otop_im,
    output signed [15:0] obot_re,
    output signed [15:0] obot_im
);

  // Helper function for rounding
  function signed [25:0] RND(input signed [25:0] x, input integer s);
    begin
      RND = (x + (1 << (s-1))) >>> s;
    end
  endfunction

  // Compute twiddle factors
  wire signed [25:0] mult_result_re = $signed(bot_re) * $signed(w_re) - $signed(bot_im) * $signed(w_im);
  wire signed [25:0] mult_result_im = $signed(bot_re) * $signed(w_im) + $signed(bot_im) * $signed(w_re);

  // Round the twiddle factor products
  wire signed [15:0] tr = RND(mult_result_re, 7);
  wire signed [15:0] ti = RND(mult_result_im, 7);

  // Calculate the butterfly outputs with rounding and saturation
  assign otop_re = $signed(sat16(RND($signed(top_re) + $signed(tr), 1)));
  assign otop_im = $signed(sat16(RND($signed(top_im) + $signed(ti), 1)));
  assign obot_re = $signed(sat16(RND($signed(top_re) - $signed(tr), 1)));
  assign obot_im = $signed(sat16(RND($signed(top_im) - $signed(ti), 1)));

  // Saturation function
  function signed [15:0] sat16;
    input signed [25:0] x;
    begin
      if(x > 32767) sat16 = 32767;
      else if(x < -32768) sat16 = -32768;
      else sat16 = x[15:0];
    end
  endfunction

endmodule