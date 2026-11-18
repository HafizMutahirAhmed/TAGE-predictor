// -----------------------------------------------------------------------------
// tage_defines.vh
// Shared TAGE configuration (Verilog-2001 replacement of the old tage_pkg).
// Include it at file scope:   `include "tage_defines.vh"
//
// Meta bundle (META_W = 72 bits), MSB first - same layout as tage_predict:
//     meta = { prov[2:0], alt[2:0], idx4..idx1, tag4..tag1, pred, alt_pred }
//       prov     = meta[71:69]
//       alt      = meta[68:66]
//       idx      = meta[65:34]   (idx of table t at bits [34 + (t-1)*8 +: 8])
//       tag      = meta[33:2]    (tag of table t at bits [ 2 + (t-1)*8 +: 8])
//       pred     = meta[1]
//       alt_pred = meta[0]
// -----------------------------------------------------------------------------
`ifndef TAGE_DEFINES_VH
`define TAGE_DEFINES_VH

`define TAGE_NUM_T       4      // Number of tagged tables (T1..T4)
`define TAGE_HIST_LEN_1  4      // History lengths for T1..T4
`define TAGE_HIST_LEN_2  8
`define TAGE_HIST_LEN_3  16
`define TAGE_HIST_LEN_4  32
`define TAGE_IDX_W       8      // Tagged table index width (256 entries = 8 bits)
`define TAGE_TAG_W       8      // Tag width
`define TAGE_CTR_W       3      // Tagged table counter width
`define TAGE_BASE_IDX_W  10     // Base table index width (1K entries = 10 bits)
`define TAGE_META_W      72     // 3+3+4*8+4*8+1+1

// meta field selects, e.g. meta[`META_PROV], meta[`META_IDX_T(t)]
`define META_PROV        71:69
`define META_ALT         68:66
`define META_IDX         65:34
`define META_TAG         33:2
`define META_PRED        1
`define META_ALT_PRED    0
`define META_IDX_T(t)    (34 + ((t) - 1) * 8) +: 8
`define META_TAG_T(t)    (2 + ((t) - 1) * 8) +: 8

`endif
