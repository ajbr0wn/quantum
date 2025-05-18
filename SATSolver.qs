namespace SATSolver {

    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Math;

    // Literal: (variable index, polarity)
    newtype Literal = (Int, Bool);

    // Disjunction (OR) of literals
    newtype Clause = Literal[];

    // Conjunction (AND) of clauses
    newtype CNFFormula = Clause[];

    function DefineSATProblem(numVariables : Int, clauses : Clause[]) : (Int, CNFFormula) {
        return (numVariables, CNFFormula(clauses));
    }

    // Evaluate if a literal is satisfied by a variable assignment
    function EvaluateLiteral(lit : Literal, assignment : Bool[]) : Bool {
        let (varIdx, polarity) = lit!;
        let value = assignment[varIdx - 1];
        return value == polarity;
    }

    // Evaluate if a clause is satisfied by a variable assignment
    function EvaluateClause(clause : Clause, assignment : Bool[]) : Bool {
        let literals = clause!;

        for lit in literals {
            if (EvaluateLiteral(lit, assignment)) {
                return true;
            }
        }

        return false;
    }

    // Evaluate if an entire CNF formula is satisfied by a variable assignment
    function EvaluateCNF(formula : CNFFormula, assignment : Bool[]) : Bool {
        let clauses = formula!;

        for clause in clauses {
            if (not EvaluateClause(clause, assignment)) {
                return false;
            }
        }

        return true;
    }


    operation ConstructOracle(numVars : Int, formula : CNFFormula) : ((Qubit[]) => Unit is Adj + Ctl) {
        return ApplyMarking(numVars, formula, _);
    }

    operation ApplyMarking(numVars : Int, formula : CNFFormula, qubits : Qubit[]) : Unit is Adj + Ctl {
        within {
            ApplyVariableEncoding(qubits);
        } apply {
            EvaluateCNFQuantum(formula, qubits);
        }
    }

    // Encode variables as qubits (converts from computational basis to variable assignments)
    operation ApplyVariableEncoding(qubits : Qubit[]) : Unit is Adj + Ctl {
        //Apply slight rotation to bias toward |1⟩ states
        for q in qubits {
            Ry(0.1, q); // Small rotation to slightly bias toward |1⟩
        }
    }

    // Apply phase flip if satisfied
    operation EvaluateCNFQuantum(formula : CNFFormula, qubits : Qubit[]) : Unit is Adj + Ctl {
        use result = Qubit();

        within {
            ComputeSatisfaction(formula, qubits, result);
        } apply {
            Z(result);
        }
    }

    operation ComputeSatisfaction(formula : CNFFormula, qubits : Qubit[], target : Qubit) : Unit is Adj + Ctl {
        let clauses = formula!;

        X(target);

        for clause in clauses {
            use clauseResult = Qubit();

            ComputeClauseSatisfaction(clause, qubits, clauseResult);

            Controlled X([clauseResult], target);
            Adjoint ComputeClauseSatisfaction(clause, qubits, clauseResult);
        }
    }

    operation ComputeClauseSatisfaction(clause : Clause, qubits : Qubit[], target : Qubit) : Unit is Adj + Ctl {
        let literals = clause!;

        for lit in literals {
            let (varIdx, polarity) = lit!;

            if (polarity) {
                Controlled X([qubits[varIdx - 1]], target);
            } else {
                within {
                    X(qubits[varIdx - 1]);
                } apply {
                    Controlled X([qubits[varIdx - 1]], target);
                }
            }
        }
    }

    operation PrepareUniformSuperposition(qubits : Qubit[]) : Unit is Adj + Ctl {
        // Apply Hadamard gate to each qubit
        ApplyToEachCA(H, qubits);
    }

    // Apply the diffusion operator
    operation ApplyDiffusionOperator(qubits : Qubit[]) : Unit is Adj + Ctl {
        within {
            // Transform |s⟩ to |0⟩
            ApplyToEachCA(H, qubits);
            ApplyToEachCA(X, qubits);
        } apply {
            // Perform reflection about |0⟩
            Controlled Z(qubits[1...], qubits[0]);
        }
    }

    // Calculate optimal number of Grover iterations
    function CalculateOptimalIterations(numVars : Int, estimatedSolutions : Int) : Int {
        // π/4 * sqrt(N/M) where N = 2^numVars and M = estimatedSolutions
        let N = 2.0^IntAsDouble(numVars);
        let M = IntAsDouble(estimatedSolutions);

        // Calculate the optimal number of iterations
        let theta = ArcSin(Sqrt(M / N));
        let optimalIters = Round(0.25 * PI() / theta);

        return optimalIters > 0 ? optimalIters | 1;
    }

    operation ApplyGroverIteration(oracle : (Qubit[] => Unit is Adj + Ctl), qubits : Qubit[]) : Unit is Adj + Ctl {
        oracle(qubits);
        ApplyDiffusionOperator(qubits);
    }

    operation RunSATSolver(numVars : Int, formula : CNFFormula, numIterations : Int) : Bool[] {
        use qubits = Qubit[numVars];

        let oracle = ConstructOracle(numVars, formula);

        PrepareUniformSuperposition(qubits);

        for _ in 1..numIterations {
            ApplyGroverIteration(oracle, qubits);
        }

        return MeasureResult(qubits);
    }

    operation MeasureResult(qubits : Qubit[]) : Bool[] {
        mutable result = [false, size = Length(qubits)];

        for i in 0..Length(qubits) - 1 {
            if (M(qubits[i]) == One) {
                set result w/= i <- true;
            } else {
                set result w/= i <- false;
            }
        }

        ResetAll(qubits);

        return result;
    }

    operation SolveSAT(numVars : Int, clauses : Clause[], estimatedSolutions : Int) : (Bool[], Bool) {
        let (_, formula) = DefineSATProblem(numVars, clauses);
        let iterations = CalculateOptimalIterations(numVars, estimatedSolutions);
        let result = RunSATSolver(numVars, formula, iterations);
        let isSatisfied = EvaluateCNF(formula, result);

        return (result, isSatisfied);
    }

    function FormatSolution(solution : Bool[]) : String {
        mutable result = "";

        for i in 0..Length(solution) - 1 {
            set result += solution[i] ? $"x{i + 1}=true" | $"x{i + 1}=false";

            if (i < Length(solution) - 1) {
                set result += ", ";
            }
        }

        return result;
    }

    @EntryPoint()
    operation TestSATSolver() : Unit {
        // (x₁ ∨ ¬x₂ ∨ x₃) ∧ (¬x₁ ∨ x₂ ∨ ¬x₃) ∧ (x₁ ∨ x₂ ∨ x₃)
        let clause1 = Clause([Literal(1, true), Literal(2, false), Literal(3, true)]);
        let clause2 = Clause([Literal(1, false), Literal(2, true), Literal(3, false)]);
        let clause3 = Clause([Literal(1, true), Literal(2, true), Literal(3, true)]);

        // Number of variables = 3
        let (solution, isSatisfied) = SolveSAT(3, [clause1, clause2, clause3], 1);

        if (isSatisfied) {
            Message($"Formula is satisfiable!");
            Message($"Solution: {FormatSolution(solution)}");
        } else {
            Message("No solution found. Try increasing iterations or check if the problem is unsatisfiable.");
        }
    }
}