class_name SessionSeed
extends RefCounted
## Session seed rules (IS-058b; S3 addendum `Game.session_seed()`). Node-free; Game (host) picks the seed of every job, NPC code derives
## its own seeds from it.
## Policy (`pick`): `--seed=N` given -> N for the first job of the process and `derive(N, job, "job")` for later jobs ("Again" /
## restart, brain loop: reproducible but not identical); not given and an automation run -> 0 for every job; otherwise (real game) a new
## random non-zero seed for every job.
## Seed 0 is today's behaviour: `derive(0, base, salt)` returns `base` unchanged (owner_tuning.agenda_seed, population_tuning.
## population_seed, civilian serial, `agenda_seed_override`). A non-zero session seed mixes as
## `hash("<session>:<base>:<salt>") & 0x7FFFFFFF` (documented, stable for a Godot version; salts keep the consumers independent).

## Salts of the consumers (one per random stream).
const SALT_OWNER_AGENDA := "owner_agenda"
const SALT_POPULATION := "population"
const SALT_CIVILIAN_ROUTE := "civilian_route"
const SALT_JOB := "job"
## Upper bound of a random seed (positive 31-bit; 0 is reserved for "today's behaviour").
const RANDOM_MAX := 0x7FFFFFFF


## Seed of a consumer: `base` when the session seed is 0, else the documented mix of both and `salt`.
static func derive(session_seed: int, base: int, salt: String) -> int:
	if session_seed == 0:
		return base
	return hash("%d:%d:%s" % [session_seed, base, salt]) & RANDOM_MAX


## Session seed of job `job_index` (0 = first job of the process). `given`/`value`: `--seed`; `automated`: test/automation run;
## `rng`: source of the random seed of a real game (never returns 0 there).
static func pick(job_index: int, given: bool, value: int, automated: bool, rng: RandomNumberGenerator) -> int:
	if given:
		return value if job_index <= 0 or value == 0 else derive(value, job_index, SALT_JOB)
	if automated:
		return 0
	return rng.randi_range(1, RANDOM_MAX)
