;; University of Groningen (UG) Academy Building Fire Evacuation Model
;; Agent Based Model written for the UG course 'Agent Technology Practical'
;; Developed between October 18 and December 14 2025
;; All code written from scratch by David van Wuijkhuijse (d.g.a.van.wuijkhuijse@student.rug.nl)

patches-own [
  is-ground-floor?            ;; ground floor is on the right side of the screen
  is-stairs?                  ;; stairs are marked by pcolor cyan
  is-honors-stairs?           ;; honors stairs are marked by dark blue patch color
  is-fire-escape-stairs?      ;; fire escape stairs are marked by purple patch color
  is-walkable?                ;; walkable tiles are marked by pcolor white or stairs
  is-exit?                    ;; exits are marked by green tiles
  is-burning?                 ;; burning tiles have a red pcolor

  smoke-level                 ;; int value for level of smoke
  heat-level                  ;; int value for level of heat, used for spreading fire

  distance-to-main-exit       ;; distance to main exit(s)
  distance-to-second-exit     ;; distance to second exit
  distance-to-fire-exit       ;; distance to fire exit
  distance-to-main-stairs     ;; distance to the main stairway
  distance-to-honors-stairs   ;; distance to the stairs in the honors college entrance
  distance-to-fire-stairs     ;; distance to the stairs in the fire escape
  linked-stair-patch          ;; link stairs together for simpler calculations
  exit-counter                ;; per-tick exit output
]

turtles-own [
  current-floor       ;; track current floor for stair behavior
  spatial-knowledge   ;; either random, low, medium, high

  health              ;; health value used for agents in fire
]


globals [
  total-agents                                               ;; number of agents initialized on setup
  agents-survived agents-died                                ;; set of variables that measure total survival and deceased counts
  high-survived medium-survived low-survived random-survived ;; variables that measure survival per spatial knowledge group
  high-died medium-died low-died random-died                 ;; variables that measure deceased per spatial knowledge group

  total-evacuation-times
  high-evacuation-times
  medium-evacuation-times                                    ;; list of all evacuation times
  low-evacuation-times
  random-evacuation-times
]

;; GLOBAL FUNCTIONS ;;

;; setup function that initializes everything for the model to run
to setup
  import-image-to-world

  ask patches [
    set is-ground-floor? (pxcor >= (min-pxcor + max-pxcor) / 2)
    ;; different stair variables needed for distance calculations
    set is-stairs? (pcolor = 85.2)
    set is-honors-stairs? (pcolor = 104.9)
    set is-fire-escape-stairs? (pcolor = 125.7)
    set is-exit? (pcolor = 64.9)
    set is-walkable? (pcolor = white or is-exit? or is-stairs? or is-honors-stairs? or is-fire-escape-stairs?)
    set is-burning? false
    set heat-level 0
    set linked-stair-patch nobody
    set exit-counter 0
  ]

  ;; observer setup functions
  setup-stairs    ;; support stairs in both directions

  ;; compute distances to exits on ground-floor
  compute-distance-main-exit
  compute-distance-second-exit
  compute-distance-fire-escape

  ;; compute distances to stairs on first floor
  compute-distance-stairs
  compute-distance-honors-stairs
  compute-distance-fire-escape-stairs

  ;; set random patch on fire
  ask one-of patches with [pcolor = white] [
    ignite
  ]

  initialize-reporter-variables
end

;; main loop function that moves the agents, spreads fire and enforces logic
to go
  if not any? turtles [
    stop
  ]

  ask patches with [is-exit?] [
    set exit-counter 0
  ]

  ask turtles [
    (ifelse
      spatial-knowledge = "high" [
        move-high-knowledge
      ]
      spatial-knowledge = "medium" [
        move-medium-knowledge
      ]
      spatial-knowledge = "low" [
        move-low-knowledge
      ]
      spatial-knowledge = "random" [
        random-walk
      ]
      [
        show ("No knowledge assigned!")
      ]
    )

    if [is-stairs? or is-honors-stairs? or is-fire-escape-stairs?] of patch-here [
      move-stairs
    ]


    if [is-exit?] of patch-here [
      if [exit-counter] of patch-here < exit-capacity [
        ask patch-here [set exit-counter exit-counter + 1]
        ;; adjust counters
        set agents-survived agents-survived + 1

        ;; increase count of knowledge group and add evacuation time
        let time ticks
        set total-evacuation-times lput time total-evacuation-times
        if spatial-knowledge = "high" [
          set high-survived high-survived + 1
          set high-evacuation-times lput time high-evacuation-times
        ]
        if spatial-knowledge = "medium" [
          set medium-survived medium-survived + 1
          set medium-evacuation-times lput time medium-evacuation-times
        ]
        if spatial-knowledge = "low" [
          set low-survived low-survived + 1
          set low-evacuation-times lput time low-evacuation-times
        ]
        if spatial-knowledge = "random" [
          set random-survived random-survived + 1
          set random-evacuation-times lput time random-evacuation-times
        ]
        die
      ]
    ]

    if [is-burning?] of patch-here [
      set health health - 10
    ]

    if [smoke-level > 40] of patch-here [
      set health health - 2
    ]

    if health <= 0 [
      ;; adjust counters
      set agents-died agents-died + 1

      if spatial-knowledge = "high"       [set high-died high-died + 1]
      if spatial-knowledge = "medium"     [set medium-died medium-died + 1]
      if spatial-knowledge = "low"        [set low-died low-died + 1]
      if spatial-knowledge = "random"     [set random-died random-died + 1]
      die
    ]
  ]


  ;; update BFS every 5 ticks -> increase model performance
  if ticks mod 5 = 0 [
    ;; compute distances to exits on ground-floor
    compute-distance-main-exit
    compute-distance-second-exit
    compute-distance-fire-escape

    ;; compute distances to stairs on first floor
    compute-distance-stairs
    compute-distance-honors-stairs
    compute-distance-fire-escape-stairs
  ]


  ;; call fire related functions
  spread-fire
  spread-smoke
  visualize-fire

  tick
end

;; REPORTER FUNCTIONS ;;
;; initialization function to set all variables used for reporting
to initialize-reporter-variables
  ;; all global variables are just set here,
  ;; which are used for reporting statistics
  set total-agents count turtles
  set agents-survived 0
  set agents-died 0

  set high-survived 0
  set medium-survived 0
  set low-survived 0
  set random-survived 0
  set high-died 0
  set medium-died 0
  set low-died 0
  set random-died 0

  ;; initialize evacuation times per group
  set total-evacuation-times []
  set high-evacuation-times []
  set medium-evacuation-times []
  set low-evacuation-times []
  set random-evacuation-times []
end

;; reporter function for the survival rate (agents that survived / all agents)
to-report survival-rate
  report agents-survived / total-agents
end

;; reporter function for reporting overall and per group evacuation times
to-report avg-evacuation-times
  let overall-avg ifelse-value empty? total-evacuation-times [0] [mean total-evacuation-times]
  let high-avg    ifelse-value empty? high-evacuation-times [0] [mean high-evacuation-times]
  let med-avg     ifelse-value empty? medium-evacuation-times [0] [mean medium-evacuation-times]
  let low-avg     ifelse-value empty? low-evacuation-times [0] [mean low-evacuation-times]
  let rand-avg    ifelse-value empty? random-evacuation-times [0] [mean random-evacuation-times]

  report (list overall-avg high-avg med-avg low-avg rand-avg)
end

;; function that neatly summarizes everything for behaviorspace
to-report simulation-summary
  ;; calculate survival rates per group ;;
  ;; find total amount of agents per group
  let total-high   (high-survived + high-died)
  let total-medium    (medium-survived + medium-died)
  let total-low    (low-survived + low-died)
  let total-random   (random-survived + random-died)

  ;; simple survival rate per group
  let surv-rate-high high-survived / total-high
  let surv-rate-medium medium-survived / total-medium
  let surv-rate-low low-survived / total-low
  let surv-rate-random random-survived / total-random

  let surv-rate-overall agents-survived / total-agents

  ;; calculate evacuation times per group ;;
  ;; same as function avg-evacuation-times!, just used seperately so we can report all variables at once
  let overall-avg ifelse-value empty? total-evacuation-times [0] [mean total-evacuation-times]
  let high-avg    ifelse-value empty? high-evacuation-times [0] [mean high-evacuation-times]
  let med-avg     ifelse-value empty? medium-evacuation-times [0] [mean medium-evacuation-times]
  let low-avg     ifelse-value empty? low-evacuation-times [0] [mean low-evacuation-times]
  let rand-avg    ifelse-value empty? random-evacuation-times [0] [mean random-evacuation-times]

  ;; report a big list of all statistics calculated above
  ;; these can be used for further analysis
  report (list
    surv-rate-high surv-rate-medium surv-rate-low surv-rate-random surv-rate-overall
    overall-avg high-avg med-avg low-avg rand-avg
  )
end

;; END GLOBAL FUNCTIONS

;; PATCH OWN FUNCTIONS ;;
;; function for spawning n amount of agents on defined floor, with knowledge group as argument
to spawn-specific-agents [target-floor n knowledge]
  repeat n [
    let candidates patches with [
      is-walkable? and is-ground-floor? = target-floor
    ]
    if any? candidates [
      ask one-of candidates [
        sprout 1 [
          set current-floor ifelse-value target-floor [0] [1]
          set spatial-knowledge knowledge
          set health 100
          set color (ifelse-value
                     spatial-knowledge = "high"    [green]
                     spatial-knowledge = "medium"  [yellow]
                     spatial-knowledge = "low"     [red]
                     [gray]
          )
          set size 1.5
        ]
      ]
    ]
  ]
end

;; function for creating n amount of agents on defined floor
to create-floor-specific-agents [n ground-floor?]
  let target-floor ground-floor?
  ifelse random-spawns? [
    ;; regular spawning mechanism
    repeat n [
      let candidates patches with [
        is-walkable? and is-ground-floor? = target-floor
      ]
      if any? candidates [
        ask one-of candidates [
          sprout 1 [
            set current-floor ifelse-value target-floor [0] [1]
            set spatial-knowledge one-of ["high" "medium" "low" "random"]
            set health 100
            set color (ifelse-value
                       spatial-knowledge = "high"    [green]
                       spatial-knowledge = "medium"  [yellow]
                       spatial-knowledge = "low"     [red]
                       [gray]
            )
            set size 1.5
          ]
        ]
      ]
    ]
  ] [
    ;; else clause, spawn based on percentages defined in environment with sliders
    let total-pct (pct-high + pct-medium + pct-low + pct-random)
    if total-pct != 1 [
      user-message "Error: Total percentage must add to 1!"
      stop
    ]
    let high-count round (n * pct-high)
    let medium-count round (n * pct-medium)
    let low-count round (n * pct-low)
    let random-count round (n * pct-random)

    spawn-specific-agents target-floor high-count "high"
    spawn-specific-agents target-floor medium-count "medium"
    spawn-specific-agents target-floor low-count "low"
    spawn-specific-agents target-floor random-count "random"
  ]
end

;; function for loading patch colors, clearing all and resetting ticks
to import-image-to-world
  clear-all
  import-pcolors "academiegebouw_map.png"
  reset-ticks
end

;; DISTANCE COMPUTATIONS ;;

;; function that calculates the BFS distance to the MAIN exit
to compute-distance-main-exit
  ;; explicitly set main exit patches distance to zero
  ask patches [
    ifelse is-exit? and pycor = 1 [
      set distance-to-main-exit 0
    ] [
      set distance-to-main-exit 10000000000
    ]
  ]

  let queue patches with [distance-to-main-exit = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-main-exit = 10000000000] [
        set distance-to-main-exit current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that calculates the BFS distance to the SECOND exit (on the left)
to compute-distance-second-exit
  ;; explicitly set second exit patches distance to zero
  ask patches [
    ifelse is-exit? and pycor = 54 [
      set distance-to-second-exit 0
    ] [
      set distance-to-second-exit 10000000000
    ]
  ]

  let queue patches with [distance-to-second-exit = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-second-exit = 10000000000] [
        set distance-to-second-exit current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that calculates the BFS distance to the FIRE exit (on the right)
to compute-distance-fire-escape
  ;; explicitly set fire escape exit patches distance to zero
  ask patches [
    ifelse is-exit? and pxcor = 225 [
      set distance-to-fire-exit 0
    ] [
      set distance-to-fire-exit 10000000000
    ]
  ]

  let queue patches with [distance-to-fire-exit = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-fire-exit = 10000000000] [
        set distance-to-fire-exit current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that calculates the BFS distance to the MAIN stairs (aqua, in the middle)
to compute-distance-stairs
  ;; explicitly set main stair patches on first floor distance to zero
  ask patches [
    ifelse is-stairs? and not is-ground-floor? [
      set distance-to-main-stairs 0
    ] [
      set distance-to-main-stairs 10000000000
    ]
  ]

  let queue patches with [distance-to-main-stairs = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-main-stairs = 10000000000] [
        set distance-to-main-stairs current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that calculates the BFS distance to the HONORS COLLEGE entrace stairs (dark blue, on the left)
to compute-distance-honors-stairs
  ;; explicitly set honors stair patches on first floor distance to zero
  ask patches [
    ifelse is-honors-stairs? and not is-ground-floor? [
      set distance-to-honors-stairs 0
    ] [
      set distance-to-honors-stairs 10000000000
    ]
  ]

  let queue patches with [distance-to-honors-stairs = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-honors-stairs = 10000000000] [
        set distance-to-honors-stairs current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that calculates the BFS distance to the FIRE ESCAPE stairs (purple, on the right)
to compute-distance-fire-escape-stairs
  ;; explicitly set fire escape stair patch on first floor distance to zero
  ask patches [
    ifelse is-fire-escape-stairs? and not is-ground-floor? [
      set distance-to-fire-stairs 0
    ] [
      set distance-to-fire-stairs 10000000000
    ]
  ]

  let queue patches with [distance-to-fire-stairs = 0]
  let current-distance 0

  ;; BFS algorithm
  while [any? queue] [
    set current-distance current-distance + 1
    let expanded no-patches
    ask queue [
      ;; ask von neumann neighbors with an unset distance to set distance
      ask neighbors4 with [is-walkable? and distance-to-fire-stairs = 10000000000] [
        set distance-to-fire-stairs current-distance
        set expanded (patch-set expanded self)
      ]
    ]
    set queue expanded
  ]
end

;; function that adds linking to stairs
to setup-stairs
  ask patches with [is-stairs? or is-honors-stairs? or is-fire-escape-stairs?] [
    ifelse is-ground-floor? [
      set linked-stair-patch patch (pxcor - 125) pycor
    ] [
      set linked-stair-patch patch (pxcor + 125) pycor
    ]
  ]
end

;; FUNCTIONS RELATED TO FIRE ;;
;; function for igniting a tile
to ignite
  set is-burning? true
  set is-walkable? false
  set heat-level 100
end

;; function that handles the fire spreading and all other logic
to spread-fire
  ask patches with [is-burning?] [
    ask neighbors with [is-walkable? and not is-burning?] [
      set heat-level min list 100 (heat-level + 5 * burn-rate)
      set smoke-level min list 100 (smoke-level + 3)
      if heat-level > 40 and not is-burning? [
        ignite
      ]
    ]

    if is-stairs? [
      ask linked-stair-patch [
        set heat-level min list 100 (heat-level + 5)
        set smoke-level min list 100 (smoke-level + 3)
        set is-stairs? false
        if heat-level > 70 and not is-burning? [
          ignite
        ]
      ]
    ]
  ]
end

;; function for visualizing fire with different colors based on heat level
to visualize-fire
  ask patches with [is-walkable?] [
    if (smoke-level > 0 and not is-exit? and not is-stairs? and not is-honors-stairs?
        and not is-fire-escape-stairs? and not is-burning?) [
      set pcolor scale-color gray smoke-level 300 50
    ]
  ]
  ask patches with [heat-level > 0] [
    if heat-level > 80 [
      set pcolor orange
    ]
    if heat-level <= 80 and heat-level > 50 [
      set pcolor yellow
    ]
    if heat-level <= 50 and heat-level > 0 [
      set pcolor red
    ]
  ]
end

;; function that handles smoke spreading
to spread-smoke
  ask patches with [smoke-level > 0 and smoke-level != 100] [
    let amount smoke-level * smoke-spread
    ask neighbors with [is-walkable?] [
      set smoke-level min list 100 (smoke-level + amount) ;; cap at 100
    ]

    if is-stairs? and linked-stair-patch != nobody [
      let direction-multiplier ifelse-value is-ground-floor? [1.5] [0.5]
      ask linked-stair-patch [
        set smoke-level min list 100 (smoke-level + amount * direction-multiplier) ;; cap at 100
      ]
    ]
  ]
end

;; END PATCH OWN FUNCTIONS ;;

;; TURTLE OWN FUNCTIONS ;;
;; MOVEMENT FUNCTIONS ;;

;; turtle function to move if on stairs
to move-stairs
  if linked-stair-patch != nobody [
    move-to linked-stair-patch
    set current-floor ifelse-value (current-floor = 0) [1] [0]
    let next-patch one-of neighbors4 with [is-walkable? and not is-stairs? and not is-honors-stairs? and not is-fire-escape-stairs?]
    ;; move off stair patch to prevent getting stuck
    if next-patch != nobody [
      move-to next-patch
    ]
  ]
end

;; function for implementing the movement of agents with high spatial knowledge
to move-high-knowledge
  ;; currently on first floor
  ifelse (current-floor = 1) [
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      let best-option min-one-of options [
        min (list distance-to-main-stairs distance-to-honors-stairs distance-to-fire-stairs)
      ]
      if best-option != nobody [
        face best-option
        move-to best-option
      ]
    ]
  ] [ ;; else ground floor and move to nearest exit
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      let best-option min-one-of options [
        min (list distance-to-main-exit distance-to-second-exit distance-to-fire-exit)
      ]
      if best-option != nobody [
        face best-option
        move-to best-option
      ]
    ]
  ]
end

;; function for implementing the movement of agents with medium spatial knowledge
to move-medium-knowledge
  ;; currently on first floor
  ifelse (current-floor = 1) [
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      ;; if fire escape nearby, go there instead
      let fire-escape-patches patches in-radius 10 with [is-fire-escape-stairs?]
      if any? fire-escape-patches [
        let best-option min-one-of options [distance-to-fire-stairs]
        face best-option
        move-to best-option
        stop
      ]
      ;; choose best option to main exit/stairs
      let best-option min-one-of options [
        min (list distance-to-main-stairs)
      ]
      if best-option != nobody [
        face best-option
        move-to best-option
      ]
    ]
  ] [ ;; else ground floor and move to nearest exit
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      ;; if fire escape nearby, go there instead
      let fire-escape-patches patches in-radius 10 with [is-fire-escape-stairs?]
      if any? fire-escape-patches [
        let best-option min-one-of options [distance-to-fire-stairs]
        face best-option
        move-to best-option
        stop
      ]
      ;; choose best option to main exit/stairs
      let best-option min-one-of options [
        min (list distance-to-main-exit)
      ]
      if best-option != nobody [
        face best-option
        move-to best-option
      ]
    ]
  ]
end

;; function for implementing the movement of agents with low spatial knowledge
to move-low-knowledge
  ;; currently on first floor
  ifelse (current-floor = 1) [
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      let stairs-patches patches in-radius 15 with [is-stairs?]
      let fire-stairs-patches patches in-radius 10 with [is-fire-escape-stairs?]

      ;; local vision
      (ifelse
        any? stairs-patches [
          ;; pick distance of tile closest to the stairs
          let best-option min-one-of options [distance-to-main-stairs]
          face best-option
          move-to best-option
        ]
        any? fire-stairs-patches [
          let best-option min-one-of options [distance-to-fire-stairs]
          face best-option
          move-to best-option
        ] [
          ;; else: move away from fire
          let nearby-patches neighbors
          let fire-patches patches in-radius 5 with [is-burning?]
          if any? fire-patches [
            let closest-fire-patch min-one-of fire-patches [distance myself]
            let safe-patches nearby-patches with [not any? turtles-here and not is-burning? and is-walkable?]

            let my-dist [distance myself] of closest-fire-patch
            let away-from-fire-patches safe-patches with [
              (distance closest-fire-patch) > my-dist
            ]

            ifelse any? away-from-fire-patches [
              move-to one-of away-from-fire-patches
            ] [
              if any? safe-patches [
                let chosen-patch one-of options ;; random walk
                face chosen-patch
                move-to chosen-patch
              ]
            ]
          ]
        ]
      )
    ]
  ] [ ;; else ground floor and move to nearest exit
    let options neighbors with [is-walkable? and not any? turtles-here]
    if any? options [
      let visible-targets patches in-radius 15 with [is-exit?]

      ;; local vision
      ifelse any? visible-targets [
        ;; pick best patch to be the patch with shortest distance to myself
        let best-option min-one-of options [
          min (list distance-to-main-exit distance-to-second-exit distance-to-fire-exit)
        ]
        face best-option
        move-to best-option
      ] [
          ;; else: move away from fire
          let nearby-patches neighbors
          let fire-patches patches in-radius 5 with [is-burning?]
          if any? fire-patches [
            let closest-fire-patch min-one-of fire-patches [distance myself]
            let safe-patches nearby-patches with [not any? turtles-here and not is-burning? and is-walkable?]

            let my-dist [distance myself] of closest-fire-patch
            let away-from-fire-patches safe-patches with [
              (distance closest-fire-patch) > my-dist
            ]

            ifelse any? away-from-fire-patches [
              move-to one-of away-from-fire-patches
            ] [
              if any? safe-patches [
              let chosen-patch one-of options ;; random walk
              face chosen-patch
              move-to chosen-patch
            ]
          ]
        ]
      ]
    ]
  ]
end

;; function that implements walking behavior for random walk agents
to random-walk
  let options neighbors with [is-walkable? and not any? turtles-here]
  if any? options [
    let chosen-patch one-of options
    face chosen-patch
    move-to chosen-patch
  ]
end
@#$#@#$#@
GRAPHICS-WINDOW
244
20
1236
249
-1
-1
4.0
1
5
1
1
1
0
0
0
1
0
245
0
54
0
0
1
ticks
30.0

BUTTON
182
218
237
251
NIL
go
T
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

BUTTON
2
218
66
251
Setup
setup
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

SLIDER
2
140
174
173
agents-on-first-floor
agents-on-first-floor
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
2
176
182
209
agents-on-ground-floor
agents-on-ground-floor
0
100
100.0
1
1
NIL
HORIZONTAL

SLIDER
3
259
175
292
burn-rate
burn-rate
0
2
2.0
0.1
1
NIL
HORIZONTAL

SLIDER
3
333
203
366
exit-capacity
exit-capacity
0
10
5.0
1
1
agents per tick
HORIZONTAL

SLIDER
3
296
175
329
smoke-spread
smoke-spread
0
1
0.06
0.01
1
NIL
HORIZONTAL

PLOT
470
259
850
458
Agents survived per group
ticks
Amount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"high-knowledge" 1.0 0 -10899396 true "" "plot high-survived"
"medium-knowledge" 1.0 0 -1184463 true "" "plot medium-survived"
"low-knowledge" 1.0 0 -2674135 true "" "plot low-survived"
"random-walk" 1.0 0 -7500403 true "" "plot random-survived"

PLOT
852
259
1233
457
Dead agents per group
ticks
Amount
0.0
10.0
0.0
10.0
true
true
"" ""
PENS
"high-deceased" 1.0 0 -10899396 true "" "plot high-died"
"medium-deceased" 1.0 0 -1184463 true "" "plot medium-died"
"low-deceased" 1.0 0 -2674135 true "" "plot low-died"
"random-deceased" 1.0 0 -7500403 true "" "plot random-died"

MONITOR
248
259
461
304
avg. high knowledge evac. time
ifelse-value empty? high-evacuation-times [0] [mean high-evacuation-times]
2
1
11

MONITOR
248
308
461
353
avg. medium knowledge evac. time
ifelse-value empty? medium-evacuation-times [0] [mean medium-evacuation-times]
2
1
11

MONITOR
273
358
461
403
avg. low knowledge evac. time
ifelse-value empty? low-evacuation-times [0] [mean low-evacuation-times]
2
1
11

MONITOR
283
408
461
453
avg. random-walk evac. time
ifelse-value empty? random-evacuation-times [0] [mean random-evacuation-times]
2
1
11

SWITCH
2
18
153
51
random-spawns?
random-spawns?
1
1
-1000

SLIDER
2
55
106
88
pct-high
pct-high
0
1
1.0
0.01
1
NIL
HORIZONTAL

SLIDER
110
55
215
88
pct-medium
pct-medium
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
2
90
107
123
pct-low
pct-low
0
1
0.0
0.01
1
NIL
HORIZONTAL

SLIDER
112
90
215
123
pct-random
pct-random
0
1
0.0
0.01
1
NIL
HORIZONTAL

BUTTON
68
218
179
251
Spawn agents
create-floor-specific-agents agents-on-ground-floor true\n  create-floor-specific-agents agents-on-first-floor false
NIL
1
T
OBSERVER
NIL
NIL
NIL
NIL
1

@#$#@#$#@
## WHAT IS IT?

(a general understanding of what the model is trying to show or explain)

## HOW IT WORKS

(what rules the agents use to create the overall behavior of the model)

## HOW TO USE IT

(how to use the model, including a description of each of the items in the Interface tab)

## THINGS TO NOTICE

(suggested things for the user to notice while running the model)

## THINGS TO TRY

(suggested things for the user to try to do (move sliders, switches, etc.) with the model)

## EXTENDING THE MODEL

(suggested things to add or change in the Code tab to make the model more complicated, detailed, accurate, etc.)

## NETLOGO FEATURES

(interesting or unusual features of NetLogo that the model uses, particularly in the Code tab; or where workarounds were needed for missing features)

## RELATED MODELS

(models in the NetLogo Models Library and elsewhere which are of related interest)

## CREDITS AND REFERENCES

(a reference to the model's URL on the web if it has one, as well as any other necessary credits, citations, and links)
@#$#@#$#@
default
true
0
Polygon -7500403 true true 150 5 40 250 150 205 260 250

airplane
true
0
Polygon -7500403 true true 150 0 135 15 120 60 120 105 15 165 15 195 120 180 135 240 105 270 120 285 150 270 180 285 210 270 165 240 180 180 285 195 285 165 180 105 180 60 165 15

arrow
true
0
Polygon -7500403 true true 150 0 0 150 105 150 105 293 195 293 195 150 300 150

box
false
0
Polygon -7500403 true true 150 285 285 225 285 75 150 135
Polygon -7500403 true true 150 135 15 75 150 15 285 75
Polygon -7500403 true true 15 75 15 225 150 285 150 135
Line -16777216 false 150 285 150 135
Line -16777216 false 150 135 15 75
Line -16777216 false 150 135 285 75

bug
true
0
Circle -7500403 true true 96 182 108
Circle -7500403 true true 110 127 80
Circle -7500403 true true 110 75 80
Line -7500403 true 150 100 80 30
Line -7500403 true 150 100 220 30

butterfly
true
0
Polygon -7500403 true true 150 165 209 199 225 225 225 255 195 270 165 255 150 240
Polygon -7500403 true true 150 165 89 198 75 225 75 255 105 270 135 255 150 240
Polygon -7500403 true true 139 148 100 105 55 90 25 90 10 105 10 135 25 180 40 195 85 194 139 163
Polygon -7500403 true true 162 150 200 105 245 90 275 90 290 105 290 135 275 180 260 195 215 195 162 165
Polygon -16777216 true false 150 255 135 225 120 150 135 120 150 105 165 120 180 150 165 225
Circle -16777216 true false 135 90 30
Line -16777216 false 150 105 195 60
Line -16777216 false 150 105 105 60

car
false
0
Polygon -7500403 true true 300 180 279 164 261 144 240 135 226 132 213 106 203 84 185 63 159 50 135 50 75 60 0 150 0 165 0 225 300 225 300 180
Circle -16777216 true false 180 180 90
Circle -16777216 true false 30 180 90
Polygon -16777216 true false 162 80 132 78 134 135 209 135 194 105 189 96 180 89
Circle -7500403 true true 47 195 58
Circle -7500403 true true 195 195 58

circle
false
0
Circle -7500403 true true 0 0 300

circle 2
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240

cow
false
0
Polygon -7500403 true true 200 193 197 249 179 249 177 196 166 187 140 189 93 191 78 179 72 211 49 209 48 181 37 149 25 120 25 89 45 72 103 84 179 75 198 76 252 64 272 81 293 103 285 121 255 121 242 118 224 167
Polygon -7500403 true true 73 210 86 251 62 249 48 208
Polygon -7500403 true true 25 114 16 195 9 204 23 213 25 200 39 123

cylinder
false
0
Circle -7500403 true true 0 0 300

dot
false
0
Circle -7500403 true true 90 90 120

face happy
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 255 90 239 62 213 47 191 67 179 90 203 109 218 150 225 192 218 210 203 227 181 251 194 236 217 212 240

face neutral
false
0
Circle -7500403 true true 8 7 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Rectangle -16777216 true false 60 195 240 225

face sad
false
0
Circle -7500403 true true 8 8 285
Circle -16777216 true false 60 75 60
Circle -16777216 true false 180 75 60
Polygon -16777216 true false 150 168 90 184 62 210 47 232 67 244 90 220 109 205 150 198 192 205 210 220 227 242 251 229 236 206 212 183

fish
false
0
Polygon -1 true false 44 131 21 87 15 86 0 120 15 150 0 180 13 214 20 212 45 166
Polygon -1 true false 135 195 119 235 95 218 76 210 46 204 60 165
Polygon -1 true false 75 45 83 77 71 103 86 114 166 78 135 60
Polygon -7500403 true true 30 136 151 77 226 81 280 119 292 146 292 160 287 170 270 195 195 210 151 212 30 166
Circle -16777216 true false 215 106 30

flag
false
0
Rectangle -7500403 true true 60 15 75 300
Polygon -7500403 true true 90 150 270 90 90 30
Line -7500403 true 75 135 90 135
Line -7500403 true 75 45 90 45

flower
false
0
Polygon -10899396 true false 135 120 165 165 180 210 180 240 150 300 165 300 195 240 195 195 165 135
Circle -7500403 true true 85 132 38
Circle -7500403 true true 130 147 38
Circle -7500403 true true 192 85 38
Circle -7500403 true true 85 40 38
Circle -7500403 true true 177 40 38
Circle -7500403 true true 177 132 38
Circle -7500403 true true 70 85 38
Circle -7500403 true true 130 25 38
Circle -7500403 true true 96 51 108
Circle -16777216 true false 113 68 74
Polygon -10899396 true false 189 233 219 188 249 173 279 188 234 218
Polygon -10899396 true false 180 255 150 210 105 210 75 240 135 240

house
false
0
Rectangle -7500403 true true 45 120 255 285
Rectangle -16777216 true false 120 210 180 285
Polygon -7500403 true true 15 120 150 15 285 120
Line -16777216 false 30 120 270 120

leaf
false
0
Polygon -7500403 true true 150 210 135 195 120 210 60 210 30 195 60 180 60 165 15 135 30 120 15 105 40 104 45 90 60 90 90 105 105 120 120 120 105 60 120 60 135 30 150 15 165 30 180 60 195 60 180 120 195 120 210 105 240 90 255 90 263 104 285 105 270 120 285 135 240 165 240 180 270 195 240 210 180 210 165 195
Polygon -7500403 true true 135 195 135 240 120 255 105 255 105 285 135 285 165 240 165 195

line
true
0
Line -7500403 true 150 0 150 300

line half
true
0
Line -7500403 true 150 0 150 150

pentagon
false
0
Polygon -7500403 true true 150 15 15 120 60 285 240 285 285 120

person
false
0
Circle -7500403 true true 110 5 80
Polygon -7500403 true true 105 90 120 195 90 285 105 300 135 300 150 225 165 300 195 300 210 285 180 195 195 90
Rectangle -7500403 true true 127 79 172 94
Polygon -7500403 true true 195 90 240 150 225 180 165 105
Polygon -7500403 true true 105 90 60 150 75 180 135 105

plant
false
0
Rectangle -7500403 true true 135 90 165 300
Polygon -7500403 true true 135 255 90 210 45 195 75 255 135 285
Polygon -7500403 true true 165 255 210 210 255 195 225 255 165 285
Polygon -7500403 true true 135 180 90 135 45 120 75 180 135 210
Polygon -7500403 true true 165 180 165 210 225 180 255 120 210 135
Polygon -7500403 true true 135 105 90 60 45 45 75 105 135 135
Polygon -7500403 true true 165 105 165 135 225 105 255 45 210 60
Polygon -7500403 true true 135 90 120 45 150 15 180 45 165 90

sheep
false
15
Circle -1 true true 203 65 88
Circle -1 true true 70 65 162
Circle -1 true true 150 105 120
Polygon -7500403 true false 218 120 240 165 255 165 278 120
Circle -7500403 true false 214 72 67
Rectangle -1 true true 164 223 179 298
Polygon -1 true true 45 285 30 285 30 240 15 195 45 210
Circle -1 true true 3 83 150
Rectangle -1 true true 65 221 80 296
Polygon -1 true true 195 285 210 285 210 240 240 210 195 210
Polygon -7500403 true false 276 85 285 105 302 99 294 83
Polygon -7500403 true false 219 85 210 105 193 99 201 83

square
false
0
Rectangle -7500403 true true 30 30 270 270

square 2
false
0
Rectangle -7500403 true true 30 30 270 270
Rectangle -16777216 true false 60 60 240 240

star
false
0
Polygon -7500403 true true 151 1 185 108 298 108 207 175 242 282 151 216 59 282 94 175 3 108 116 108

target
false
0
Circle -7500403 true true 0 0 300
Circle -16777216 true false 30 30 240
Circle -7500403 true true 60 60 180
Circle -16777216 true false 90 90 120
Circle -7500403 true true 120 120 60

tree
false
0
Circle -7500403 true true 118 3 94
Rectangle -6459832 true false 120 195 180 300
Circle -7500403 true true 65 21 108
Circle -7500403 true true 116 41 127
Circle -7500403 true true 45 90 120
Circle -7500403 true true 104 74 152

triangle
false
0
Polygon -7500403 true true 150 30 15 255 285 255

triangle 2
false
0
Polygon -7500403 true true 150 30 15 255 285 255
Polygon -16777216 true false 151 99 225 223 75 224

truck
false
0
Rectangle -7500403 true true 4 45 195 187
Polygon -7500403 true true 296 193 296 150 259 134 244 104 208 104 207 194
Rectangle -1 true false 195 60 195 105
Polygon -16777216 true false 238 112 252 141 219 141 218 112
Circle -16777216 true false 234 174 42
Rectangle -7500403 true true 181 185 214 194
Circle -16777216 true false 144 174 42
Circle -16777216 true false 24 174 42
Circle -7500403 false true 24 174 42
Circle -7500403 false true 144 174 42
Circle -7500403 false true 234 174 42

turtle
true
0
Polygon -10899396 true false 215 204 240 233 246 254 228 266 215 252 193 210
Polygon -10899396 true false 195 90 225 75 245 75 260 89 269 108 261 124 240 105 225 105 210 105
Polygon -10899396 true false 105 90 75 75 55 75 40 89 31 108 39 124 60 105 75 105 90 105
Polygon -10899396 true false 132 85 134 64 107 51 108 17 150 2 192 18 192 52 169 65 172 87
Polygon -10899396 true false 85 204 60 233 54 254 72 266 85 252 107 210
Polygon -7500403 true true 119 75 179 75 209 101 224 135 220 225 175 261 128 261 81 224 74 135 88 99

wheel
false
0
Circle -7500403 true true 3 3 294
Circle -16777216 true false 30 30 240
Line -7500403 true 150 285 150 15
Line -7500403 true 15 150 285 150
Circle -7500403 true true 120 120 60
Line -7500403 true 216 40 79 269
Line -7500403 true 40 84 269 221
Line -7500403 true 40 216 269 79
Line -7500403 true 84 40 221 269

wolf
false
0
Polygon -16777216 true false 253 133 245 131 245 133
Polygon -7500403 true true 2 194 13 197 30 191 38 193 38 205 20 226 20 257 27 265 38 266 40 260 31 253 31 230 60 206 68 198 75 209 66 228 65 243 82 261 84 268 100 267 103 261 77 239 79 231 100 207 98 196 119 201 143 202 160 195 166 210 172 213 173 238 167 251 160 248 154 265 169 264 178 247 186 240 198 260 200 271 217 271 219 262 207 258 195 230 192 198 210 184 227 164 242 144 259 145 284 151 277 141 293 140 299 134 297 127 273 119 270 105
Polygon -7500403 true true -1 195 14 180 36 166 40 153 53 140 82 131 134 133 159 126 188 115 227 108 236 102 238 98 268 86 269 92 281 87 269 103 269 113

x
false
0
Polygon -7500403 true true 270 75 225 30 30 225 75 270
Polygon -7500403 true true 30 75 75 30 270 225 225 270
@#$#@#$#@
NetLogo 6.4.0
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
@#$#@#$#@
default
0.0
-0.2 0 0.0 1.0
0.0 1 1.0 0.0
0.2 0 0.0 1.0
link direction
true
0
Line -7500403 true 150 150 90 180
Line -7500403 true 150 150 210 180
@#$#@#$#@
0
@#$#@#$#@
