module two_point_dft_tb;

    localparam int NUM_TESTS = 5;

    logic signed [15:0] x0_i;
    logic signed [15:0] x0_q;
    logic signed [15:0] x1_i;
    logic signed [15:0] x1_q;

    logic signed [15:0] X0_i;
    logic signed [15:0] X0_q;
    logic signed [15:0] X1_i;
    logic signed [15:0] X1_q;

    logic [63:0] input_vectors    [0:NUM_TESTS-1];
    logic [63:0] expected_vectors [0:NUM_TESTS-1];

    logic signed [15:0] expected_X0_i;
    logic signed [15:0] expected_X0_q;
    logic signed [15:0] expected_X1_i;
    logic signed [15:0] expected_X1_q;

    integer test_index;
    integer errors;

    two_point_dft dut (
        .x0_i(x0_i),
        .x0_q(x0_q),
        .x1_i(x1_i),
        .x1_q(x1_q),
        .X0_i(X0_i),
        .X0_q(X0_q),
        .X1_i(X1_i),
        .X1_q(X1_q)
    );

    initial begin
        $dumpfile("two_point_dft.vcd");
        $dumpvars(0, two_point_dft_tb);

        $readmemh(
            "vectors/two_point_inputs.hex",
            input_vectors
        );

        $readmemh(
            "vectors/two_point_expected.hex",
            expected_vectors
        );

        x0_i = 0;
        x0_q = 0;
        x1_i = 0;
        x1_q = 0;
        errors = 0;

        for (
            test_index = 0;
            test_index < NUM_TESTS;
            test_index = test_index + 1
        ) begin
            x0_i = input_vectors[test_index][63:48];
            x0_q = input_vectors[test_index][47:32];
            x1_i = input_vectors[test_index][31:16];
            x1_q = input_vectors[test_index][15:0];

            $display("x0_i: %0d, x0_q: %0d, x1_i: %0d, x1_q: %0d", x0_i, x0_q, x1_i, x1_q);

            expected_X0_i =
                expected_vectors[test_index][63:48];
            expected_X0_q =
                expected_vectors[test_index][47:32];
            expected_X1_i =
                expected_vectors[test_index][31:16];
            expected_X1_q =
                expected_vectors[test_index][15:0];

            $display("OUTPUT X0_i: %0d, X0_q: %0d, X1_i: %0d, X1_q: %0d", X0_i, X0_q, X1_i, X1_q);
            $display("EXPECTED X0_i: %0d, X0_q: %0d, X1_i: %0d, X1_q: %0d", expected_X0_i, expected_X0_q, expected_X1_i, expected_X1_q);

            #1;

            if (
                X0_i !== expected_X0_i ||
                X0_q !== expected_X0_q ||
                X1_i !== expected_X1_i ||
                X1_q !== expected_X1_q
            ) begin
                $error(
                    "Mismatch %0d: expected X0=(%0d,%0d), X1=(%0d,%0d); got X0=(%0d,%0d), X1=(%0d,%0d)",
                    test_index,
                    expected_X0_i,
                    expected_X0_q,
                    expected_X1_i,
                    expected_X1_q,
                    X0_i,
                    X0_q,
                    X1_i,
                    X1_q
                );

                errors = errors + 1;
            end else begin
                $display(
                    "PASS %0d: X0=(%0d,%0d), X1=(%0d,%0d)",
                    test_index,
                    X0_i,
                    X0_q,
                    X1_i,
                    X1_q
                );
            end
        end

        if (errors == 0)
            $display(
                "PASS: all %0d vectors matched",
                NUM_TESTS
            );
        else
            $fatal(
                1,
                "FAIL: %0d of %0d vectors mismatched",
                errors,
                NUM_TESTS
            );

        $finish;
    end

endmodule
