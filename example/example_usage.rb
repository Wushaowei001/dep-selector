require 'pp'
require 'dep_selector'

# This example corresponds to the following dependency graph:
#   A has versions: 1, 2
#   B has versions: 1, 2, 3
#   C has versions: 1, 2
#   D has versions: 1, 2
#   A1 -> B=1         (v1 of package A depends on v1 of package B)
#   A2 -> B>=2, C=1   (v2 of package A depends on B at v2 or greater and v1 of C)
#   B3 -> D=1         (v3 of package B depends on v1 of package D)
#   C2 -> D=2         (v2 of package C depends on v2 of package D)

include DepSelector

# create dependency graph
dep_graph = DependencyGraph.new

# package A has versions 1 and 2
a = dep_graph.package('A')
a1 = a.add_version(Version.new('1.0.0'))
a2 = a.add_version(Version.new('2.0.0'))

# package B has versions 1, 2, and 3
b = dep_graph.package('B')
b1 = b.add_version(Version.new('1.0.0'))
b2 = b.add_version(Version.new('2.0.0'))
b3 = b.add_version(Version.new('3.0.0'))

# package C only has versions 1 and 2
c = dep_graph.package('C')
c1 = c.add_version(Version.new('1.0.0'))
c2 = c.add_version(Version.new('2.0.0'))

# package D only has versions 1 and 2
d = dep_graph.package('D')
d1 = d.add_version(Version.new('1.0.0'))
d2 = d.add_version(Version.new('2.0.0'))

# package A version 1 has a dependency on package B at exactly 1.0.0
# Note: Though we reference the variable b in the Dependency, packages
# do not have to be created before being referenced.
# DependencyGraph#package looks up the package based on the name or
# auto-vivifies it if it doesn't yet exist, so referring to the
# variable b or calling dep_graph.package('B') before or after b is
# assigned are all equivalent.
a1.dependencies << Dependency.new(b, VersionConstraint.new('= 1.0.0'))
a1.dependencies << Dependency.new(d, VersionConstraint.new('= 2.0.0'))

# package A version 2 has dependencies on package B >= 2.0.0 and C at exactly 1.0.0
a2.dependencies << Dependency.new(b, VersionConstraint.new('>= 2.0.0'))
a2.dependencies << Dependency.new(c, VersionConstraint.new('= 1.0.0'))

# package B version 3 has a dependency on package D at exactly 1.0.0
b3.dependencies << Dependency.new(d, VersionConstraint.new('= 1.0.0'))

# package C version 2 has a dependency on package D at exactly 2.0.0
c2.dependencies << Dependency.new(d, VersionConstraint.new('= 2.0.0'))

# create a Selector from the dependency graph
selector = Selector.new(dep_graph)

# define the solution constraints and find a solution

# simple solution: any version of A as long as B is at exactly 1.0.0
solution_constraints_1 = [
                          SolutionConstraint.new(dep_graph.package('A')),
                          SolutionConstraint.new(dep_graph.package('B'), VersionConstraint.new('= 1.0.0'))
                         ]
pp selector.find_solution(solution_constraints_1)

# more complex solution, which uses a range constraint (>=) and
# demonstrates the assignment of induced transitive dependencies
solution_constraints_2 = [
                          SolutionConstraint.new(dep_graph.package('A')),
                          SolutionConstraint.new(dep_graph.package('B'), VersionConstraint.new('>= 2.1'))
                         ]
pp selector.find_solution(solution_constraints_2)

# When the solution constraints are unsatisfiable, a NoSolutionExists
# exception is raised. It identifies what the first solution
# constraint that makes the system unsatisfiable is. It also
# identifies the package(s) (either direct solution constraints or
# induced dependencies) whose constraints caused the
# unsatisfiability. The exception's message contains the name of one
# of the packages, as well as paths through the dependency graph that
# result in constraints on the package to hint at places to debug.
unsatisfiable_solution_constraints_1 = [
                                        SolutionConstraint.new(dep_graph.package('B'), VersionConstraint.new('= 3.0.0')),
                                        SolutionConstraint.new(dep_graph.package('C'), VersionConstraint.new('= 2.0.0'))
                                       ]
# Note that package D is identified as the most constrained package
# and the paths from from solution constraints to constraints on D are
# returned in the message
begin
  selector.find_solution(unsatisfiable_solution_constraints_1)
rescue Exceptions::NoSolutionExists => nse
  pp nse.message
end

# Now, let's create a package, depends_on_nosuch, that has a
# dependency on a non-existent package, nosuch, and see that nosuch is
# identified as the problematic package. Note that because Package
# objects are auto-vivified by DependencyGraph#Package, non-existent
# packages are any packages that have no versions.
depends_on_nosuch = dep_graph.package('depends_on_nosuch')
depends_on_nosuch_v1 = depends_on_nosuch.add_version(Version.new('1.0'))
depends_on_nosuch_v1.dependencies << Dependency.new(dep_graph.package('nosuch'))

unsatisfiable_solution_constraints_2 = [ SolutionConstraint.new(depends_on_nosuch) ]
# Note that package D is identified as the most constrained package
# and the paths from from solution constraints to constraints on D are
# returned in the message
begin
  selector.find_solution(unsatisfiable_solution_constraints_2)
rescue Exceptions::NoSolutionExists => nse
  pp nse.message
end

# Invalid solution constraints are those that reference a non-existent
# package, or constrain an extant package to no versions. All invalid
# solution constraints are raised in an InvalidSolutionConstraints
# exception.
invalid_solution_constraints = [
                                SolutionConstraint.new(dep_graph.package('nosuch')),
                                SolutionConstraint.new(dep_graph.package('nosuch2')),
                                SolutionConstraint.new(dep_graph.package('A'), VersionConstraint.new('>= 10.0.0')),
                                SolutionConstraint.new(dep_graph.package('B'), VersionConstraint.new('>= 50.0.0'))
                               ]
begin
  selector.find_solution(invalid_solution_constraints)
rescue Exceptions::InvalidSolutionConstraints => isc
  puts "non-existent solution constraints: #{isc.non_existent_packages.join(', ')}"
  puts "solution constraints whose constraints match no versions of the package: #{isc.constrained_to_no_versions.join(', ')}"
end
