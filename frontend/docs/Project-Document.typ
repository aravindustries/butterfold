#set page(
  paper: "a4",
  margin: (x: 2.5cm, y: 2.5cm)
)
#set heading(numbering: "1.")


#align(center)[
  #v(30%)

  #title[Butterfold]

  Folding all the way
]

#pagebreak()

#metadata("contents") <contents>
#outline()

#pagebreak()

#set page(
  header: context {
    let current_page = here().page()

    let chapters = query(
      selector(heading.where(level: 1))
    )

    let current_chapter = none

    for ch in chapters {
      if ch.location().page() <= current_page {
        current_chapter = ch
      }
    }

    if current_chapter != none {
      if current_chapter.location().page() == current_page {
        align(right)[
          #link(<contents>)[Contents]
        ]
      }
      else {
        align(right)[
          #link(current_chapter.location())[
            #current_chapter.body
          ]
        ]
      }
    }
  },

  footer: context {
    align(center)[
      #counter(page).display()
    ]
  }
)

= 5G PHY
\<Need to populate\>

#pagebreak()

= Chipathon Constraints
#figure(
  image("assets/die_breakdown.jpeg", width: 53%),
  caption: [
    Team level allocation of the die
  ]
)

#figure(
  table(
    columns: (auto, auto, auto),
    align: horizon,
    table.header(
      [Field], [Parameters #sub[(max)]], [Description]
    ),
    [Power], [5V #sym.times 0.5A], [Not confirmed],
    [Area], [3.05mm #sym.times 1.6mm], [Not confirmed],
    [Pins], [22 + 1(VDD) + 1(GND)], [Padframe A],
    [F#sub[clk]], [150MHz], [],
  ),
  caption: [
    Process constraints
  ]
)

// NOTE: use the sram macro provided by the container
LibreLane standard cells operate at 5.0V (upon inspection of the macros in the docker container)
SRAM can also be configured to use 5.0V

== Section 2.1
#figure(
  image("assets/5G PHY-Pinout.png", width: 50%),
  caption: [
    Expected pinout
  ]
)


#table(
  columns: (auto, auto, auto),
  align: horizon,
  table.header(
    [Pin], [Name], [Direction]
  ),
  [1],  [mode],           [Input (Digital)],
  [2],  [mac_clk],        [Input (Digital)],
  [3],  [mac_data[0]],    [Bidirectional (Digital)],
  [4],  [mac_data[1]],    [Bidirectional (Digital)],
  [5],  [mac_data[2]],    [Bidirectional (Digital)],
  [6],  [mac_data[3]],    [Bidirectional (Digital)],
  [7],  [mac_data[4]],    [Bidirectional (Digital)],
  [8],  [mac_data[5]],    [Bidirectional (Digital)],
  [9],  [mac_data[6]],    [Bidirectional (Digital)],
  [10], [mac_data[7]],    [Bidirectional (Digital)],
  [11], [mac_data_valid], [Bidirectional (Digital)],
  [12], [arst_n],         [Input (Digital)],
  [13], [core_clk],       [Input (Digital)],
  [14], [rf_data[0]],     [Bidirectional (Digital)],
  [15], [rf_data[1]],     [Bidirectional (Digital)],
  [16], [rf_data[2]],     [Bidirectional (Digital)],
  [17], [rf_data[3]],     [Bidirectional (Digital)],
  [18], [rf_data[4]],     [Bidirectional (Digital)],
  [19], [rf_data[5]],     [Bidirectional (Digital)],
  [20], [rf_data[6]],     [Bidirectional (Digital)],
  [21], [rf_data[7]],     [Bidirectional (Digital)],
  [22], [rf_data_valid],  [Bidirectional (Digital)],
)

#figure(
  image("assets/area_budget.png", width: 106%),
  caption: [
    Area budget
  ]
)

// for impl keep photo of pinout

