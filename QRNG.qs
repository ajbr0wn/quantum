namespace Quantum.QRNG {
    open Microsoft.Quantum.Intrinsic;
    open Microsoft.Quantum.Measurement;
    open Microsoft.Quantum.Diagnostics;
    open Microsoft.Quantum.Convert;
    open Microsoft.Quantum.Arrays;
    open Microsoft.Quantum.Math;

    operation GenerateRandomNumberWithVisualization(nBits : Int, maxValue : Int) : Int {
        Message("\n========================================================");
        Message("    Quantum Random Number Generator");
        Message("========================================================\n");
        Message($"Generating a random number between 0 and {maxValue} using {nBits} qubits");

        mutable resultArray = [Zero, size = nBits];

        use qubits = Qubit[nBits] {
            Message("\n--- Initial State ---");
            Message("All qubits initialized in |0⟩ state");
            DumpMachine();

            Message("\n--- Creating Superposition ---");
            Message("Applying Hadamard gates to each qubit...");

            for idx in 0..nBits-1 {
                H(qubits[idx]);
                Message($"Applied H gate on qubit {idx}");
            }

            Message("\n--- Superposition State ---");
            Message("Qubits now in superposition - equal probability of 0 and 1");
            DumpMachine();

            Message("\n--- Measurement Process ---");
            Message("Measuring each qubit to collapse the superposition...");

            mutable binaryString = "";
            for idx in 0..nBits-1 {
                let result = MResetZ(qubits[idx]);
                set resultArray w/= idx <- result;
                set binaryString = binaryString + (result == One ? "1" | "0");
                Message($"Qubit {idx}: Measured {result}");
            }

            Message("\n--- Final State (After Measurement) ---");
            Message("All qubits have collapsed to classical states");
            DumpMachine();
        }

        let randomInt = ResultArrayAsInt(resultArray);
        let scaledNumber = randomInt % (maxValue + 1);

        mutable binaryString = "";
        for res in resultArray {
            set binaryString = binaryString + (res == One ? "1" | "0");
        }

        Message("\n========================================================");
        Message("                     QRNG RESULTS                       ");
        Message("--------------------------------------------------------");
        Message($"Binary outcome:        {binaryString}");
        Message($"Decimal value:         {randomInt}");
        Message($"Scaled random number:  {scaledNumber} (0-{maxValue} range)");
        Message("========================================================\n");

        return scaledNumber;
    }

    operation GenerateRandomNumber(nBits : Int, maxValue : Int) : Int {
        Message($"Generating a random number between 0 and {maxValue} using {nBits} qubits");
        Message("-----------------------------------------------------");

        mutable resultArray = [Zero, size = nBits];

        use qubits = Qubit[nBits] {
            Message("Initial state: All qubits in |0⟩ state");
            DumpMachine();

            Message("Applying Hadamard gates to create superposition...");
            for idx in 0..nBits-1 {
                H(qubits[idx]);
            }

            Message("Qubits now in superposition state:");
            DumpMachine();

            Message("Measuring qubits...");
            for idx in 0..nBits-1 {
                set resultArray w/= idx <- MResetZ(qubits[idx]);
                Message($"Qubit {idx}: Measured {resultArray[idx]}");
            }
        }

        let randomInt = ResultArrayAsInt(resultArray);
        let scaledNumber = randomInt % (maxValue + 1);

        Message("-----------------------------------------------------");
        Message($"Binary result: {BoolArrayAsString(ResultArrayAsBoolArray(resultArray))}");
        Message($"Random number generated: {scaledNumber}");

        return scaledNumber;
    }

    function BoolArrayAsString(boolArray : Bool[]) : String {
        mutable binaryString = "";
        for bit in boolArray {
            set binaryString = binaryString + (bit ? "1" | "0");
        }
        return binaryString;
    }

    @EntryPoint()
    operation RunQRNG() : Unit {
        let numberOfBits = 3;
        let maxValue = 7;
        let numberOfSamples = 5;

        Message("=== Quantum Random Number Generator Demo ===");
        Message($"Configured to generate {numberOfBits}-bit random numbers (0-{maxValue})");
        Message($"Will generate {numberOfSamples} random samples\n");

        mutable results = [0, size = numberOfSamples];  // Initialize Int array with zeros

        for i in 0..numberOfSamples - 1 {
            Message($"\n=== Generating Sample #{i + 1} ===");

            if (i == 0) {
                let randomNumber = GenerateRandomNumberWithVisualization(numberOfBits, maxValue);
                set results w/= i <- randomNumber;
            } else {
                let randomNumber = GenerateRandomNumber(numberOfBits, maxValue);
                set results w/= i <- randomNumber;
            }
        }

        Message("\n=== Results Summary ===");
        for i in 0..numberOfSamples - 1 {
            Message($"Sample #{i + 1}: {results[i]}");
        }

        let sum = SumArrayElements(results);
        let avg = IntAsDouble(sum) / IntAsDouble(numberOfSamples);

        Message($"\nAverage value: {avg}");
        Message($"Expected average for true random distribution: {IntAsDouble(maxValue) / 2.0}");
        Message("\nThank you for using the Quantum Random Number Generator!");
    }

    function SumArrayElements(array : Int[]) : Int {
        mutable sum = 0;
        for element in array {
            set sum += element;
        }
        return sum;
    }
}