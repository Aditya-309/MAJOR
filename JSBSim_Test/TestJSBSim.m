clear;
clc;

%% JSBSim Installation

JSBSimRoot = ...
    "C:\Users\lalit\AppData\Local\JSBSim";

JSBSimExe = fullfile( ...
    JSBSimRoot, ...
    "JSBSim.exe");

%% Check Installation

if ~isfile(JSBSimExe)

    error( ...
        "JSBSim executable not found at: %s", ...
        JSBSimExe);

end

disp("JSBSim executable found.");

%% Check C172P Aircraft

AircraftFile = fullfile( ...
    JSBSimRoot, ...
    "aircraft", ...
    "c172p", ...
    "c172p.xml");

if ~isfile(AircraftFile)

    error( ...
        "C172P aircraft file not found at: %s", ...
        AircraftFile);

end

disp("C172P aircraft file found.");

%% Check Initialization File

InitFile = fullfile( ...
    JSBSimRoot, ...
    "aircraft", ...
    "c172p", ...
    "reset00.xml");

if ~isfile(InitFile)

    error( ...
        "C172P initialization file not found at: %s", ...
        InitFile);

end

disp("C172P initialization file found.");

%% Run JSBSim

Command = sprintf( ...
    '"%s" --root="%s" --aircraft=c172p --initfile="%s" --end=10', ...
    JSBSimExe, ...
    JSBSimRoot, ...
    InitFile);

disp(" ");
disp("Running JSBSim...");
disp(Command);
disp(" ");

[Status, CommandOutput] = system(Command);

%% Display Result

disp(CommandOutput);

if Status ~= 0

    error( ...
        "JSBSim execution failed with status %d.", ...
        Status);

end

disp(" ");
disp("JSBSim executed successfully with C172P.");