OPENROAD ?= openroad
ARRANGEMENT ?= C
STAGE ?= route

.PHONY: synth floorplan place cts route timing pdn all clean \
	physical-signoff-setup physical-signoff-hold physical-signoff-io \
	physical-signoff-summary

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

clean:
	rm -rf results
