# We provide a basic test set that stores results, and doesn't throw
# any exceptions until the end of the test set.
immutable BasicTestSet <: AbstractTestSet
    description::String
    results::Vector
end

BasicTestSet() = BasicTestSet("", [])
BasicTestSet(desc) = BasicTestSet(desc, [])

record(ts::BasicTestSet, t::Pass) = push!(ts.results, t)

function record(ts::BasicTestSet, t::Union(Fail,Error))
    print_with_color(:white, ts.description, ": ")
    println(t)
    push!(ts.results, t)
end

record(ts::BasicTestSet, t::AbstractTestSet) = push!(ts.results, t)

function finish(ts::BasicTestSet)
    # If we are a nested test set, do not print a full summary
    # now - let the parent test set do the printing
    if get_testset_depth() != 0
        # Attach this test set to the parent test set
        parent_ts = get_testset()
        record(parent_ts, ts)
        return
    end
    # Calculate the alignment of the test result counts
    align = _get_alignment(ts, 0)
    # Print the outer test set header once
    print_with_color(:white, "Test Summary:\n")
    # Recursively print a summary at every level
    _print_counts(ts, 0, align)
end

function _get_alignment(ts::BasicTestSet, depth::Int)
    ts_width = 2*depth + length(ts.description)
    for t in ts.results
        if isa(t, BasicTestSet)
            ts_width = max(ts_width, _get_alignment(t, depth+1))
        end
    end
    ts_width
end

function _get_test_counts(ts::BasicTestSet)
    num_pass, num_fail, num_error = 0, 0, 0
    num_child_pass, num_child_fail, num_child_error = 0, 0, 0
    for t in ts.results
        isa(t, Pass)  && (num_pass  += 1)
        isa(t, Fail)  && (num_fail  += 1)
        isa(t, Error) && (num_error += 1)
        if isa(t, BasicTestSet)
            np, nf, ne, ncp, ncf, nce = _get_test_counts(t)
            num_child_pass += np + ncp
            num_child_fail += nf + ncf
            num_child_error += ne + nce
        end
    end
    return num_pass, num_fail, num_error,
            num_child_pass, num_child_fail, num_child_error
end

function _print_counts(ts::BasicTestSet, depth::Int, align::Int)
    # We must be the root test set
    # Count results by each type at this level, and recursively
    # through and child test sets
    num_pass, num_fail, num_error,
        num_child_pass, num_child_fail, num_child_error =
            _get_test_counts(ts)
    num_test = num_pass + num_fail + num_error +
                num_child_pass + num_child_fail + num_child_error

    # Print test set header, with an alignment that ensures all
    # the test results appear above each other
    print(rpad(string("  "^depth, ts.description), align, " "), " |  ")

    np = num_pass + num_child_pass
    if np > 0
        print_with_color(:green, "Pass: ")
        @printf("%d (%5.1f %%)  ", np, np/num_test*100)
    end
    nf = num_fail + num_child_fail
    if nf > 0
        print_with_color(:red, "Fail: ")
        @printf("%d (%5.1f %%)  ", nf, nf/num_test*100)
    end
    ne = num_error + num_child_error
    if ne > 0
        print_with_color(:red, "Error: ")
        @printf("%d (%5.1f %%)  ", ne, ne/num_test*100)
    end
    if np == 0 && nf == 0 && ne == 0
        print_with_color(:blue, "No tests")
    end
    println()

    for t in ts.results
        if isa(t, BasicTestSet)
            _print_counts(t, depth + 1, align)
        end
    end
end