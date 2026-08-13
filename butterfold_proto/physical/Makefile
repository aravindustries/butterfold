OPENROAD ?= openroad
PYTHON ?= python3
PDKPATH ?= /foss/pdks/gf180mcuD
ARRANGEMENT ?= C
STAGE ?= route

.PHONY: synth floorplan place cts route timing pdn all clean \
	physical-signoff-setup physical-signoff-hold physical-signoff-io \
	physical-signoff-summary padframe-build padframe-smoke padframe-floorplan \
	padframe-place padframe-cts padframe-route padframe-signoff padframe-summary \
	pad-boundary-repair candidate-gds

.PHONY: padframe-electrical

synth:
	$(MAKE) -C .. -f Makefile.gf180_sram synth-sta

floorplan: synth
	PHYS_STAGE=floorplan MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit flow.tcl

place: synth
	PHYS_STAGE=place MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit flow.tcl

cts: synth
	PHYS_STAGE=cts MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit flow.tcl

route: synth
	PHYS_STAGE=route MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit flow.tcl

timing:
	MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit extract_route.tcl
	MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit analyze_extracted.tcl

pdn:
	MACRO_ARRANGEMENT=$(ARRANGEMENT) $(OPENROAD) -no_init -exit pdn_from_floorplan.tcl

all: route timing

# Extracted multi-corner sensitivity analysis of the retained detailed route.
# SIGNOFF_IO_CONTRACT=0 reproduces the historical zero-delay core-pin model;
# =1 applies the candidate pad-pin contract documented in
# PAD_IO_MULTICORNER_TIMING_REPORT.md.  It is not a substitute for selecting
# authoritative Padframe-A cells and package/board timing.
physical-signoff-setup:
	SIGNOFF_CORNER=ss_125C_4v50 SIGNOFF_RC=max SIGNOFF_IO_CONTRACT=1 $(OPENROAD) -no_init -exit signoff_sta.tcl

physical-signoff-hold:
	SIGNOFF_CORNER=ff_n40C_5v50 SIGNOFF_RC=min SIGNOFF_IO_CONTRACT=1 $(OPENROAD) -no_init -exit signoff_sta.tcl

physical-signoff-io:
	SIGNOFF_CORNER=ss_125C_4v50 $(OPENROAD) -no_init -exit pad_delay_sta.tcl
	SIGNOFF_CORNER=tt_025C_5v00 $(OPENROAD) -no_init -exit pad_delay_sta.tcl
	SIGNOFF_CORNER=ff_n40C_5v50 $(OPENROAD) -no_init -exit pad_delay_sta.tcl

physical-signoff-summary: physical-signoff-io
	SIGNOFF_CORNER=ss_125C_4v50 SIGNOFF_RC=max SIGNOFF_IO_CONTRACT=0 $(OPENROAD) -no_init -exit signoff_sta.tcl
	SIGNOFF_CORNER=tt_025C_5v00 SIGNOFF_RC=nom SIGNOFF_IO_CONTRACT=0 $(OPENROAD) -no_init -exit signoff_sta.tcl
	SIGNOFF_CORNER=ff_n40C_5v50 SIGNOFF_RC=min SIGNOFF_IO_CONTRACT=0 $(OPENROAD) -no_init -exit signoff_sta.tcl
	SIGNOFF_CORNER=ss_125C_4v50 SIGNOFF_RC=max SIGNOFF_IO_CONTRACT=1 $(OPENROAD) -no_init -exit signoff_sta.tcl
	SIGNOFF_CORNER=tt_025C_5v00 SIGNOFF_RC=nom SIGNOFF_IO_CONTRACT=1 $(OPENROAD) -no_init -exit signoff_sta.tcl
	SIGNOFF_CORNER=ff_n40C_5v50 SIGNOFF_RC=min SIGNOFF_IO_CONTRACT=1 $(OPENROAD) -no_init -exit signoff_sta.tcl

padframe-build:
	$(MAKE) -C .. -f Makefile.gf180_sram synth-sta

padframe-smoke:
	$(MAKE) -C .. -f Makefile.gf180_sram padframe-smoke

padframe-floorplan: padframe-build
	PADFRAME_STAGE=floorplan $(OPENROAD) -no_init -exit padframe_flow.tcl

padframe-place: padframe-build
	PADFRAME_STAGE=place $(OPENROAD) -no_init -exit padframe_flow.tcl

padframe-electrical:
	PAD_ELECTRICAL_STAGE=place $(OPENROAD) -no_init -exit padframe_electrical.tcl

padframe-cts: padframe-build
	PADFRAME_STAGE=cts $(OPENROAD) -no_init -exit padframe_flow.tcl

padframe-route: padframe-build
	PADFRAME_STAGE=route $(OPENROAD) -no_init -exit padframe_flow.tcl

padframe-signoff:
	SIGNOFF_CORNER=ss_125C_4v50 SIGNOFF_RC=max $(OPENROAD) -no_init -exit padframe_signoff.tcl
	SIGNOFF_CORNER=tt_025C_5v00 SIGNOFF_RC=nom $(OPENROAD) -no_init -exit padframe_signoff.tcl
	SIGNOFF_CORNER=ff_n40C_5v50 SIGNOFF_RC=min $(OPENROAD) -no_init -exit padframe_signoff.tcl

padframe-summary: padframe-signoff
	@for f in results/padframe/signoff/*/*wns.rpt results/padframe/signoff/*/*tns.rpt; do echo "$$f"; sed -n '1,4p' "$$f"; done

# Non-signoff stream-out of the existing authoritative routed padframe ODB.
# This does not rerun or modify any P&R stage.
candidate-gds:
	mkdir -p results/padframe/gds
	STREAMOUT_DEF=results/padframe/gds/route_for_streamout.def \
		$(OPENROAD) -no_init -exit streamout_odb.tcl
	ROUTE_DEF=results/padframe/gds/route_for_streamout.def \
		OUTPUT_GDS=results/padframe/gds/butterfold_padframe_candidate.gds \
		PDKPATH=$(PDKPATH) \
		$(PYTHON) streamout_gds.py

# Hierarchical connectivity comparison using Magic, Netgen, and foundry LEF
# leaf boundaries.  This does not re-extract foundry-cell transistors.
lvs:
	$(PYTHON) run_lvs.py

lvs-diagnostic:
	$(PYTHON) audit_lvs_pins.py

clean:
	rm -rf results

# Focused repair/rebuild from the existing CTS database.  This updates only
# top-level BPin ownership and regenerates routed artifacts.
pad-boundary-repair:
	$(OPENROAD) -no_init -exit padframe_route_resume.tcl
