// =============================================================================
// Module  : round_robin_arbiter
// Desc    : Parameterized Round-Robin Arbiter for N requesters
//           - Strict fairness: no requester starves
//           - Dynamic priority pointer (last-served tracking)
//           - One-hot grant output
//           - Optional grant mask: grant only when resource is free
//           - Zero-latency combinational grant + registered state update
// =============================================================================

module round_robin_arbiter #(
    parameter N = 4   // Number of requesters (2–16 recommended)
)(
    input  wire         clk,
    input  wire         rst_n,

    input  wire [N-1:0] req,      // Request vector (1 = requesting)
    input  wire         resource_free, // 1 = resource available to grant

    output reg  [N-1:0] grant,    // One-hot grant (registered)
    output reg          valid      // 1 = a grant was issued this cycle
);

// =============================================================================
// Priority pointer — tracks index AFTER last granted requester
// =============================================================================
reg [$clog2(N)-1:0] ptr;   // "start scanning from here" pointer

// =============================================================================
// Combinational: find next grant starting from ptr
//
// Classic trick: double the request vector to avoid modulo logic
//   masked_req = req rotated so ptr is at bit 0
//   find lowest set bit in masked_req → that's the winner
// =============================================================================
reg [2*N-1:0] double_req;
reg [2*N-1:0] double_grant;
reg [N-1:0]   grant_next;
integer i;

always @(*) begin
    // Rotate request vector: put ptr at position 0
    double_req   = {req, req} >> ptr;

    // Find lowest set bit (priority encoder on rotated vector)
    double_grant = 0;
    grant_next   = 0;

    // Only find winner when resource is free and any request exists
    if (resource_free && (req != 0)) begin
        // Isolate lowest set bit: x & (-x) in two's complement
        double_grant = double_req & (~double_req + 1'b1);

        // Rotate grant back to original indexing
        // The winning bit in double_grant maps to index (bit_pos + ptr) % N
        for (i = 0; i < N; i = i + 1) begin
            if (double_grant[i] || double_grant[i + N])
                grant_next[i] = 1'b1;
        end
    end
end

// =============================================================================
// Registered output + pointer update
// =============================================================================
integer j;

always @(posedge clk) begin
    if (!rst_n) begin
        grant <= 0;
        valid <= 0;
        ptr   <= 0;
    end else begin
        grant <= grant_next;
        valid <= (grant_next != 0);

        // Advance pointer to (winner_index + 1) % N
        if (grant_next != 0) begin
            for (j = 0; j < N; j = j + 1) begin
                if (grant_next[j])
                    ptr <= (j + 1) % N;
            end
        end
    end
end

endmodule
