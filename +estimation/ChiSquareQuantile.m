function Q = ChiSquareQuantile(Probability, DoF)
%CHISQUAREQUANTILE Chi-square quantile via the Wilson-Hilferty transform.
%
%   Q = CHISQUAREQUANTILE(Probability, DoF) returns the quantile of the
%   chi-square distribution with DoF degrees of freedom at the given
%   cumulative probability (0 < Probability < 1).
%
%   The Wilson-Hilferty approximation
%
%       Q ~= DoF * (1 - 2/(9*DoF) + z*sqrt(2/(9*DoF)))^3
%
%   with z = sqrt(2)*erfinv(2*Probability-1) is used so that the core
%   Block 10 code has no dependency on the Statistics and Machine Learning
%   Toolbox (an optional toolbox that must not be required by the serial
%   implementation). Accuracy is sufficient for documented consistency
%   thresholds; the numerical test suite checks this function against
%   tabulated chi-square values where the optional toolbox is available.
%
%   DoF must be a positive integer scalar. Probability must be a finite
%   real scalar strictly between 0 and 1.
%
%   INTERNAL function. Not part of the public Block 10 API.
%
%   See also: CalculateConfidence, DetectModelMismatch,
%   BuildInvestigationEvents.

    if ~(isnumeric(Probability) && isreal(Probability) && ...
            isscalar(Probability) && isfinite(Probability) && ...
            Probability > 0 && Probability < 1)

        error( ...
            'Estimation:ChiSquareQuantile:InvalidProbability', ...
            ['Probability must be a finite real scalar strictly ', ...
             'between 0 and 1.']);

    end

    if ~(isnumeric(DoF) && isreal(DoF) && isscalar(DoF) && ...
            isfinite(DoF) && DoF >= 1 && DoF == floor(DoF))

        error( ...
            'Estimation:ChiSquareQuantile:InvalidDoF', ...
            'DoF must be a positive integer scalar.');

    end

    Z = sqrt(2) * erfinv(2 * Probability - 1);
    Term = 1 - 2 / (9 * DoF) + Z * sqrt(2 / (9 * DoF));
    Q = DoF * Term ^ 3;

end
