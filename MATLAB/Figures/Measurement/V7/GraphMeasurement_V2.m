function [Line, Prob, TotalTime, ProbsIdealTransfer, SweepRatesIdealTransfer] = ...
    GraphMeasurement_V2(Level, Worst, Rabi, Sweep, Measurement)
%This function graphs the best fidelity of a measurement, for each sweep rate.
%It returns the following variables
%RabiTimeProb: matrix with 3 columns, containing optimal Rabi rate, optimal
%Time (calcualted from the optimal sweeprate), and the optimal probability
%given these two optimized parameters
%Line: The fidelity line that was graphed
%ProbIdeal: The ideal probability broken out from RabiTimeProb
%TotalTIme: The total time broken out from RabiTimeProb
%The inputs needed are
%Level: the d in qudit for this measurement. 3-level, 5-level, or 7-level
%currently
%Worst: Whether or not we're looking at the worst case. true or false
%Rabi: The vector for the Rabi frequencies
%Sweep: The vector for the sweeprates

G = getGlobals_V2;

%Get the parameters for this calculation
if Level == 3
    index = 1;
    %Get the initial ground and excited state populations statuses
    LevelsG = G.Levels3G;
    LevelsP = G.Levels3P;
elseif Level == 5
    index = 2;
    %Get the initial ground and excited state populations statuses
    LevelsG = G.Levels5G;
    LevelsP = G.Levels5P;
elseif Level == 7
    index = 3;
    %Get the initial ground and excited state populations statuses
    LevelsG = G.Levels7G;
    LevelsP = G.Levels7P;
end
%Get the color for this line
Color = G.Colors(index, :);
%Get the style for this line
if Worst
    LineStyle = G.WorstLineStyle;
else
    LineStyle = cell2mat(G.LineStyles(index));
end

%Prepare for storing information on optimal transfers
k = 0;
ProbsIdealTransfer = [];
SweepRatesIdealTransfer = [];

%Go through the measurement sequence, shelving, deshelving, hiding, or
%fluorescing
disp("Starting Populations");
disp("     LevelsG    LevelsP");
disp([LevelsG LevelsP]);
Prob = 1;
for i = 1:size(Measurement, 1)
    MeasurementStep = Measurement(i, :);
    %Type of measurement: Shelve, Deshelve, Fluoresce, Hide
    Type = MeasurementStep(1);
    MeasurementStep = str2double(MeasurementStep(2:3));
    %Catch if tried to use level that doesn't exist
    if any(MeasurementStep < 1 | MeasurementStep > 8)
        fprintf("Step number %i %s for d = %i failed. \nState number specified is out of range of possible levels.\n", i, Type, Level);
        continue
    else
        fprintf("Step number %i\n", i);
    end
    if Type == "Shelve"
        %Catch if we forgot to specify a level in a transfer
        if any(isnan(MeasurementStep))
            fprintf("Step number %i %s for d = %i failed. \nOne of the states not specified. \n", i, Type, Level);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Get the levels involved in the transfer
        Lower = MeasurementStep(1);
        Upper = MeasurementStep(2);
        %Get the actual F values for this lower level we're depopulating
        LowerLevel = LevelsG(Lower, :);
        %Catch error of trying to transfer population that's not there
        if all(isnan(LowerLevel))
            fprintf("Step number %i %s for d = %i failed. \nThis state number %d is not populated. \n", i, Type, Level, Lower);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Catch if we're trying to drive into an already populated state
        if ~all(isnan(LevelsP(Upper, :)))
            disp("Error 2");
            fprintf("Step number %i %s for d = %i failed. \nThe state number %d is already populated. \n", i, Type, Level);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        k = k + 1;
        %Set the upper level matrix entry equal to this
        LevelsP(Upper, :) = G.LevelsAll(Upper, :);
        fprintf("Shelving F=%i, mF=%i into state F'=%i, mF'=%i\n", LowerLevel(1), LowerLevel(2), LevelsP(Upper, 1), LevelsP(Upper, 2));
        %Get probability for this transfer
        [ProbTransfer, TotalTimeTransfer] = TransferProbV2(G, Sweep, Rabi, Level, LowerLevel, LevelsP(Upper, :), LevelsG, LevelsP);
        if i == 1
            TotalTime = zeros(1, size(TotalTimeTransfer, 2));
        end
        [ProbsIdealTransfer(k, :), index] = max(ProbTransfer);
        SweepRatesIdealTransfer(k, :) = Sweep(index);
        TimeTransferOpt = zeros(1, length(index));
        for j = 1:length(index)
            TimeTransferOpt(j) = TotalTimeTransfer(index(j));
        end
        TotalTime = TotalTime + TimeTransferOpt;
        Prob = Prob.*ProbsIdealTransfer(k,:);
        %Finished transfer, make change to lower level
        LevelsG(Lower, :) = [NaN NaN];
    elseif Type == "Deshelve"
        %Catch if we forgot to specify a level in a transfer
        if any(isnan(MeasurementStep))
            fprintf("Step number %i %s for d = %i failed. \nOne of the states not specified. \n", i, Type, Level);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Catch if we're trying to deshelve before shelving
        if ~exist('TotalTime', 'var')
            fprintf("Step number %i %s for d = %i failed. \nTried to deshelve before shelving anything.\n", i, Type, Level);
            continue;
        end
        %Get the levels involved in the transfer
        Upper = MeasurementStep(1);
        Lower = MeasurementStep(2);
        %Get the actual F values for this upper level we're depopulating
        UpperLevel = LevelsP(Upper, :);
        %Catch error of trying to transfer population that's not there
        if all(isnan(UpperLevel))
            fprintf("Step number %i %s for d = %i failed. \nThis state number %d is not populated. \n", i, Type, Level, Lower);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Catch if we're trying to drive into an already populated state
        if ~all(isnan(LevelsG(Lower, :)))
            fprintf("Step number %i %s for d = %i failed. \nThis state number %d is already populated. \n", i, Type, Level, Lower);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Set the lower level matrix entry equal to this
        LevelsG(Lower, :) = G.LevelsAll(Lower, :);
        fprintf("Deshelving F'=%i, mF'=%i into state F=%i, mF=%i\n", UpperLevel(1), UpperLevel(2), LevelsG(Lower, 1), LevelsG(Lower, 2));
        %Get probability for this transfer
        [ProbTransfer, TotalTimeTransfer] = TransferProbV2(G, Sweep, Rabi, Level, UpperLevel, LevelsG(Lower, :), LevelsG, LevelsP);
        k = k + 1;
        [ProbsIdealTransfer(k, :), index] = max(ProbTransfer);
        SweepRatesIdealTransfer(k, :) = Sweep(index);
        TimeTransferOpt = zeros(1, length(index));
        for j = 1:length(index)
            TimeTransferOpt(j) = TotalTimeTransfer(index(j));
        end
        TotalTime = TotalTime + TimeTransferOpt;
        Prob = Prob.*ProbsIdealTransfer(k,:);
        %Finished transfer, make change to upper level
        LevelsP(Upper, :) = [NaN NaN];
    elseif Type == "Hide"
        %Catch if we forgot to specify a level in a transfer
        if any(isnan(MeasurementStep))
            fprintf("Step number %i %s for d = %i failed. \nOne of the states not specified. \n", i, Type, Level);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Get the levels involved in the transfer
        Initial = MeasurementStep(1);
        Final = MeasurementStep(2);
        %Get the actual F values for this initial level
        InitialLevel = LevelsG(Initial, :);
        %Catch error of trying to transfer population that's not there
        if all(isnan(InitialLevel))
            fprintf("Step number %i %s for d = %i failed. \nThis state number %d is not populated. \n", i, Type, Level, Lower);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Catch if we're trying to drive into an already populated state
        if ~all(isnan(LevelsG(Final,:)))
            fprintf("Step number %i %s for d = %i failed. \nThis state number %d is already populated.\n", i, Type, Level, Lower);
            disp("     LevelsG    LevelsP");
            disp([LevelsG LevelsP]);
            continue;
        end
        %Send the population into this new state
        LevelsG(Final,:) = G.LevelsAll(Final, :);
        fprintf("Hiding F=%i, mF=%i in state F=%i, mF=%i\n", InitialLevel(1), InitialLevel(2), LevelsG(Final, 1), LevelsG(Final, 2));
        %Erase the population from the initial state
        LevelsG(Initial,:) = [NaN NaN];
    elseif Type == "Fluoresce"
        Ground = MeasurementStep(1);
        FluoresceState = LevelsG(Ground, :);
        fprintf("Fluorescing state F=%i, mF=%i\n", FluoresceState(1), FluoresceState(2));
        LevelsG(Ground, :) = [NaN NaN];
        TotalTime = TotalTime + G.FluorescenceTime;
        Prob = Prob.*exp(-G.FluorescenceTime/G.DecayTime);
    else
        fprintf("Step number %i %s for d = %i failed. \nYou've input a measurement step name wrong. \n", i, Type, Level);
        fprintf("Make sure all steps are called ""Shelve"", ""Deshelve"", ""Hide"", or ""Fluoresce""\n");
    end
    disp("     LevelsG    LevelsP");
    disp([LevelsG LevelsP]);
    [maxx, index] = max(ProbsIdealTransfer(k,:));
    if Type == "Shelve" || Type == "Deshelve"
        fprintf("The best fidelity for this transfer is %f%%, which used a Rabi frequency of %f kHz and a sweep rate of %f MHz/ms. \n\n", ...
            maxx*100, Rabi(index)*1e-3, SweepRatesIdealTransfer(k,index)*1e-9);
    else
        fprintf("\n\n");
    end
end

if Worst
    fprintf("\n\n\n\n\n                 Worst %i-level: %f%%\n\n\n\n\n", Level, max(Prob)*100);
else
    fprintf("\n\n\n\n\n                 Ideal %i-level: %f%%\n\n\n\n\n", Level, max(Prob)*100);
end
% ProbIdeal(ProbIdeal<G.Thresh) = -inf;
Prob(Prob<G.Thresh) = -inf;
Line = semilogx(TotalTime, Prob);
hold on;
set(Line, 'Linewidth', 1.5, 'Linestyle', LineStyle, 'Color', Color);
end