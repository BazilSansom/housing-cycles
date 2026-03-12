classdef test_fiedler_mode < matlab.unittest.TestCase
    % Tests for hs.spatial.fiedler_mode

    methods (Test)
        function testEigenpairResidual(testCase)
            % Simple connected graph: path graph
            n = 10;
            A = diag(ones(n-1,1),1) + diag(ones(n-1,1),-1); % path adjacency

            [v2, evals, idx_cc] = hs.spatial.fiedler_mode(A);
            testCase.verifyEqual(numel(idx_cc), n);

            d = sum(A,2);
            L = diag(d) - A;

            % Find lambda via Rayleigh quotient
            lambda_hat = (v2' * L * v2) / (v2' * v2);

            % Residual check: Lv - lambda v is small
            r = norm(L*v2 - lambda_hat*v2) / norm(v2);
            testCase.verifyLessThan(r, 1e-6);
        end

        function testOrthogonalityToConstant(testCase)
            % For connected graph, Fiedler vector orthogonal to ones
            n = 12;
            A = diag(ones(n-1,1),1) + diag(ones(n-1,1),-1);

            v2 = hs.spatial.fiedler_mode(A);

            % v2 should have approximately zero mean (orthogonal to constant)
            testCase.verifyLessThan(abs(mean(v2)), 1e-10);
        end

        function testPathGraphMonotone(testCase)
            % Fiedler vector on path graph should be monotone up to sign
            n = 20;
            A = diag(ones(n-1,1),1) + diag(ones(n-1,1),-1);

            v2 = hs.spatial.fiedler_mode(A);

            % Monotonicity up to sign: either increasing or decreasing
            dv = diff(v2);
            isInc = all(dv >= -1e-8);
            isDec = all(dv <=  1e-8);

            testCase.verifyTrue(isInc || isDec);
        end

        function testGridGraphLongestDimension(testCase)
            % On a rectangular grid, the smoothest non-constant mode
            % should vary mainly along the longest dimension.
            nx = 10; ny = 4;  % rectangle: x longer than y
            A = localGridAdj(nx, ny);

            v2 = hs.spatial.fiedler_mode(A);

            % Reshape into grid (consistent with node indexing in localGridAdj)
            V = reshape(v2, [ny, nx]); % rows = y, cols = x

            % Variation across x vs across y: expect more across x than y
            varX = mean(var(V, 0, 2)); % variance across columns within rows
            varY = mean(var(V, 0, 1)); % variance across rows within columns

            testCase.verifyGreaterThan(varX, varY);
        end

        function testDisconnectedSelectLargestComponent(testCase)
            % Two components: sizes 8 and 5, should pick size 8
            A1 = diag(ones(7,1),1) + diag(ones(7,1),-1); % path 8
            A2 = diag(ones(4,1),1) + diag(ones(4,1),-1); % path 5

            A = blkdiag(A1, A2);

            [v2, ~, idx_cc] = hs.spatial.fiedler_mode(A);

            testCase.verifyEqual(numel(idx_cc), 8);
            testCase.verifyEqual(numel(v2), 8);
        end
    end
end

function A = localGridAdj(nx, ny)
% Build 4-neighbour grid adjacency for nx-by-ny grid.
% Node indexing: (x=1..nx, y=1..ny) mapped to linear index:
%   idx = (y-1)*nx + x
n = nx*ny;
A = sparse(n,n);

for y = 1:ny
    for x = 1:nx
        i = (y-1)*nx + x;
        if x < nx
            j = (y-1)*nx + (x+1);
            A(i,j) = 1; A(j,i) = 1;
        end
        if y < ny
            j = y*nx + x;
            A(i,j) = 1; A(j,i) = 1;
        end
    end
end
A = full(A);
end
