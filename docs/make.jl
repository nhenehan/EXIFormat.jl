# Builds the documentation with Documenter.jl:
#
#     julia --project=docs -e 'using Pkg; Pkg.instantiate()'   # once
#     julia --project=docs docs/make.jl
#
# The pages under docs/src take their code from the scripts in examples/basics, so
# the scripts stay the only copy and the pages always show their real output. In a
# page, inside a fenced block:
#
#     #! include roundtrip.jl main   the script's `# ANCHOR: main` region
#     #! include data/order.xml      a whole file
#     #! setup roundtrip.jl          the script's lines before its first ANCHOR
#                                    (its imports and includes), for an @setup block
#
# The pages with those lines filled in are written to docs/build-src (not
# committed), and Documenter builds from there. On CI, deploydocs publishes the
# result to the gh-pages branch.

using Documenter, DocumenterMermaid
import EXIFormat

const EXAMPLES = normpath(joinpath(@__DIR__, "..", "examples", "basics"))
const SRC = joinpath(@__DIR__, "src")
const GEN = joinpath(@__DIR__, "build-src")

"""The lines of `file` between `# ANCHOR: region` and `# ANCHOR_END: region`, without
the anchor lines of any region nested inside."""
function region(file, name)
    lines = readlines(joinpath(EXAMPLES, file))
    first = findfirst(==("# ANCHOR: $name"), strip.(lines))
    last = findfirst(==("# ANCHOR_END: $name"), strip.(lines))
    (first === nothing || last === nothing) && error("$file has no region $name")
    keep = filter(l -> !startswith(strip(l), "# ANCHOR"), lines[first+1:last-1])
    return join(keep, '\n')
end

"""The setup lines of a script: everything before its first ANCHOR that is not a
comment, with `include("x.jl")` made to point into examples/basics."""
function setup(file)
    out = String[]
    for line in readlines(joinpath(EXAMPLES, file))
        startswith(strip(line), "# ANCHOR") && break
        (isempty(strip(line)) || startswith(strip(line), "#")) && continue
        m = match(r"^include\(\"(.+)\"\)$", strip(line))
        push!(out, m === nothing ? line : "include($(repr(joinpath(EXAMPLES, m[1]))))")
    end
    return join(out, '\n')
end

function expand(text)
    lines = map(split(text, '\n')) do line
        m = match(r"^(\s*)#! (include|setup) (\S+)(?: (\S+))?\s*$", line)
        m === nothing && return line
        indent, what, file, name = m[1], m[2], m[3], m[4]
        body = what == "setup" ? setup(file) :
               name === nothing ? rstrip(read(joinpath(EXAMPLES, file), String)) :
               region(file, name)
        return join((isempty(l) ? l : indent * l for l in split(body, '\n')), '\n')
    end
    return join(lines, '\n')
end

rm(GEN; force = true, recursive = true)
for (dir, _, files) in walkdir(SRC), f in files
    target = joinpath(GEN, relpath(joinpath(dir, f), SRC))
    mkpath(dirname(target))
    if endswith(f, ".md")
        write(target, expand(read(joinpath(dir, f), String)))
    else
        cp(joinpath(dir, f), target)
    end
end

makedocs(
    sitename = "EXIFormat.jl",
    root = @__DIR__,
    source = "build-src",
    modules = [EXIFormat],
    repo = Remotes.GitHub("nhenehan", "EXIFormat.jl"),
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "") == "true",
        canonical = "https://nhenehan.github.io/EXIFormat.jl/stable",
        edit_link = nothing,
    ),
    pages = [
        "Home" => "index.md",
        "Manual" => [
            "manual/glossary.md",
            "manual/getting-started.md",
            "manual/roundtrip.md",
            "manual/options.md",
            "manual/read-events.md",
            "manual/write-events.md",
            "manual/structs.md",
            "manual/prebuilt-tables.md",
            "manual/errors.md",
            "manual/untrusted-input.md",
        ],
        "API reference" => [
            "api/schemas.md",
            "api/xml.md",
            "api/options.md",
            "api/events.md",
            "api/values.md",
            "api/structs.md",
            "api/errors.md",
            "api/tools.md",
        ],
        "Appendix" => [
            "appendix/side-by-side.md",
            "appendix/performance.md",
            "appendix/thanks.md",
        ],
    ],
    pagesonly = true,
    # EXIFormat has no exports, so the public names are the ones listed in the
    # API reference pages; checkdocs = :exports would check nothing.
    checkdocs = :none,
    warnonly = false,
)

if get(ENV, "CI", "") == "true"
    deploydocs(repo = "github.com/nhenehan/EXIFormat.jl.git", devbranch = "main", push_preview = false)
end
