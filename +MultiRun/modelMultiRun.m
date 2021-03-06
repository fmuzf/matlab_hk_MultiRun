function [runs, hashes, kw, combs, status, err] = modelMultiRun(modelpath, basefile, varargin)
% function modelMultiRun
%
% Args: modelpath - fully qualified path to a model's executeable
%       basefile - fully qualified path to a valid config file for the
%       model, this will be modified based upon the the list of key-value
%       pairs passed to varargin
%       varargin - a list of key-value pairs which are modified 
%          (i.e. the parameters to be calibrated), e.g.
%           modelMultiRun('debam', 'input.txt', 'icekons', [5:0.1:6])
%         will run the model with icekons set to each value in [5:0.1:6]
%
% Returns: 
%          runs - a container.Maps indexed by hashes of HashedRun objects,
%           each corresponding to a single model run.
%          hashes - Cell array of hashes of each run.
%          kw - Cell array containing names of modified values
%          combs - Array with values taken on by kws
%          status - staus(i) = Array of return status of run with hash hashes{i}
%          err - Error messages associated by incomplete runs
%          changes - array of changes made to input.txt
%          

s = fileread(basefile);    %read input.txt into string
c = MultiRun.lib.glazer.degreeToMaps(s);     %convert to container.Map style, remove text etc

%parse keyword arguments. providing a dummy if none are provided
%this is a little kludgy and could be improved somehow
%by providing an alternative procedure to handle a single run.
if isempty(varargin)    %if user does not provide any parameters to be calibrated
  kw = {'none'};        %model runs once with input.txt; kw is names of model paramters
  vals = {0};     %vals is values of kw
else    %at least one parameter to be changed is given
   [kw , vals] = MultiRun.lib.wordplay.getKwargs(varargin{:});
        %getKwargs is in /lib/wordplay
end

%give me all permutations of parameters w/in ranges provided
combs = MultiRun.lib.allcomb.allcomb(vals{:});
   % function allcomb is in /lib/allcomb/
   % creates a matrix with all parameter combinations
   
%Allocate appropriately sized cell arrays to store function returns in
nCombs = size(combs);
hashes = cell(nCombs(1), 1);
status = zeros(nCombs(1), 1);
err = cell(nCombs(1), 1);
changes = cell(nCombs(1), 1);
runs = cell(nCombs(1), 1);

for combo = 1:nCombs(1)
  %construct a message telling the user which configuration arguments
  %have been set in this run; creates the text for output file 'changes.txt'
  msg = [];
  for keynum = 1:length(kw)
    msg = [msg sprintf('  %s = %g\n', kw{keynum}, combs(combo, keynum))];
    %combs(combo, keynum)
    c(kw{keynum}) = combs(combo,keynum);  %change map to contain the altered parameter values
       %c then contains entire input.txt with all altered parameters values
  end
  
  %Build the HashedRun object, then run the model.
  HR = MultiRun.HashedRun(c, modelpath);   %modelpath is path plus detim or debam

  % RUN DETIM OR DEBAM !!!
  [runsuccess, runerr] = HR.runModel();
  
  %print to disk messages re: changes
  %TODO: this should probably be contingent on the value of runsuccess.
  % writing content of 'changes.txt'
  header = sprintf('Base config file: %s \nNew config file: %sinput.txt\n',basefile, HR.outPath);
  msg = [header sprintf('Changes made:\n') msg];
  changefile = fopen([HR.outPath 'changes.txt'],'w');
  fprintf(changefile,'%s', msg);
  fclose(changefile);
  
  %put data about run, including the run object, into the appropriate
  %return arrays
  hashes{combo} = HR.hash;
  status(combo) = runsuccess;
  err{combo} = runerr;
  changes{combo} = msg;
  runs{combo} = HR;
  disp(['Run ' int2str(combo) ' of ' int2str(nCombs(1))  ' has finished.'])
end


% --- writing multiperformance.txt ---------------------
mainOutPath = HR.originMap('outpath');
%[mainOutPath,name,ext] = fileparts(basefile);
performanceFileName = [mainOutPath 'multi_performance.txt'];
MultiRun.quality.qualityToFile(runs, kw, combs, performanceFileName);
   % function qualityToFile is in /MultiRun/quality/

disp(['Multirun has finished all runs (total of ' int2str(nCombs(1)) ' runs).']);
disp(['Model output may be viewed in ' HR.originMap('outpath')]);

end