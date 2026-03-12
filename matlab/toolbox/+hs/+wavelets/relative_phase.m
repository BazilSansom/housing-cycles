function [RPA, r, phi] = relative_phase(phaseX)
    nStates = size(phaseX,2);
    z = exp(1i*phaseX);
    order = sum(z,2)/nStates;
    r = abs(order);
    phi = angle(order);
    
    RPA = angle(exp(1i*(phaseX - phi))); % robust wrapping to [-pi,pi]
end
