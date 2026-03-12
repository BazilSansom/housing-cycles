function MRPA = mean_relative_phase(RPA, idx1, idx2)
    % circular mean of angles
    MRPA = angle(mean(exp(1i*RPA(idx1:idx2,:)),1));
    MRPA = MRPA(:);
end
