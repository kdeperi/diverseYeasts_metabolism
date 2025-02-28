%explore lactose metbolism in C. intermedia model
load('../models/candida_intermedia/cint_leloir.mat')

%Adding reactions from aspergillus niger oxidoreductive pathway. Reference:
%10.1016/j.fbr.2007.02.006
% Define reactions equations

%introducing the oxidoreductive pathway reactions from A.
%niger/A.nidulans/T.reesei. Reference:﻿﻿10.1074/jbc.M112.372755
newRxns = {'D-galactose[c] + NADPH[c] => galactitol[c] + NADP(+)[c]'... 
           'L-xylo-3-hexulose[c] + NADPH[c] + H+[c] <=> L-sorbose[c] + NADP(+)[c]'};...
           %'D-Fructose[c] + ATP[c] <=> D-Fructose-6-Phosphate[c] + ADP[c]'};
rxnsToAdd.equations = newRxns;

% Define reaction names
rxnsToAdd.rxnNames = {'aldose reductase (NAPDH)'  'L-xylo-3-hexulose reductase'};% 'hexokinase'};
rxnsToAdd.rxns     = {'ald_red_NADPH' 'xyl_hex_red'};% 'hxk'};
%Define objective and bounds
rxnsToAdd.c  = [0 0];
rxnsToAdd.lb = [0 -1000];
rxnsToAdd.ub = [1000 1000];
% %genes to add
genesToAdd.genes          = {'xyl1' 'xyl1_2' 'xyl1_3' 'G0RNA2'};
genesToAdd.geneShortNames = {'xyl1' 'xyl1_2' 'xyl1_3' 'lxr4'};  
rxnsToAdd.grRules         = {'xyl1 or xyl1_2 or xyl1_3' 'G0RNA2'};
%LEt's evaluate biomass production before integrating the pathway
model = changeMedia(model,'lac_ex',1);
sol1 = solveLP(model,1);
printFluxes(model,sol1.x)
% Introduce changes to the model
model_oxido = addGenesRaven(model,genesToAdd);
model_oxido.proteins = [model_oxido.proteins; genesToAdd.genes'];
model_oxido = addRxns(model_oxido,rxnsToAdd,3);
%Evaluate if rxn can carry flux
I  = haveFlux(model_oxido,1E-6,'ald_red_NADPH');
I2 = haveFlux(model_oxido,1E-6,'xyl_hex_red');
%LEt's evaluate biomass production
model_oxido = changeMedia(model_oxido,'lac_ex',1);
sol2 = solveLP(model_oxido,1);
printFluxes(model_oxido,sol2.x)
%Let's evaluate the whole pathway
rxns = {'ald_red_NADPH' 'r_4983' 'xyl_hex_red' 'r_5174' 'r_0323'};
fluxes=haveFlux(model_oxido,1E-6,rxns);
%All of them can carry flux, let's block galactokinase and evaluate things
%again
index = find(contains(model_oxido.rxns,'r_0458')); %Galactokinase
model_oxido.lb(index)  = 0;
model_oxido.ub(index)  = 0;
index = find(contains(model_oxido.rxns,'r_4222')); %Galactokinase
model_oxido.lb(index)  = 0;
model_oxido.ub(index)  = 0;
sol3 = solveLP(model_oxido,1);
printFluxes(model_oxido,sol3.x)
fluxes_2=haveFlux(model_oxido,1E-6,rxns);
%IT worked!!!! let's display results in a table
formulas = constructEquations(model_oxido);
%Get metabolic subSystems for each reaction
subSystems = cellfun(@strjoin,model_oxido.subSystems,transpose(repelem({' // '},length(model_oxido.subSystems))),'UniformOutput',false);
%Calculate Flux fold-Changes
FC = (sol3.x+1E-9)./([sol1.x;0;0]+1E-9);
t = table(model_oxido.rxns,model_oxido.rxnNames,formulas,model_oxido.grRules,subSystems,[sol1.x; 0; 0],sol3.x,FC);
t.Properties.VariableNames = {'rxns' 'rxnNames' 'formulas' 'grRules' 'subSystems' 'leloir' 'oxi_red_path' 'FC'};
%Discard all rxns that are not changing between conditions
t = t(t.FC~=1,:);
%There is a slight growth deffect for the galactokinase deletion strain,
%get the biomass production FChange
bioFC = t.FC(strcmpi(t.rxnNames,'biomass pseudoreaction'));
%Discard all changes that are linearly related to biomass formation
%(numerical tolerance of 0.1%)
t = t((t.FC>1.001*bioFC | t.FC<0.999*bioFC),:);
%Sort table by flux FC
t = sortrows(t,'FC','descend');
%Write results as a .txt file
writetable(t,'../results/lactose_pathways_comparison_Cint.txt','delimiter','\t','QuoteStrings',false)
%Compare flux distributions using a RAVEN built-in function
clc
followChanged(model_oxido,[sol1.x; 0; 0],sol3.x,5E-1, 1E-6, 1E-8, {'ATP'})
% Kamesh has shared that xyl1 displays cofactor cofactor promiscuity, let's
% add this to the model
% Define reaction names
rxnsToAdd = [];
newRxns = {'D-galactose[c] + NADH[c] => galactitol[c] + NAD[c]'};...
           %'D-Fructose[c] + ATP[c] <=> D-Fructose-6-Phosphate[c] + ADP[c]'};
rxnsToAdd.equations = newRxns;

rxnsToAdd.rxnNames = {'aldose reductase (NADH)'};
rxnsToAdd.rxns     = {'ald_red_NADH'};
%Define objective and bounds
rxnsToAdd.c  = 0;
rxnsToAdd.lb = 0;
rxnsToAdd.ub = 1000;
% %genes to add
rxnsToAdd.grRules = {'xyl1_2'};
% Introduce changes to the model
model_oxido = addRxns(model_oxido,rxnsToAdd,3);
%Evaluate if rxn can carry flux
I  = haveFlux(model_oxido,1E-6,'ald_red_NADH');
%Before saving the model let's unblock the Leloir pathway
%All of them can carry flux, let's block galactolkinase and evaluate things
%again
model = model_oxido;
index = find(contains(model_oxido.rxns,'r_0458')); %Galactokinase
model.lb(index)  = 0;
model.ub(index)  = 1000;
index = find(contains(model_oxido.rxns,'r_4222')); %Galactokinase
model.lb(index)  = 0;
model.ub(index)  = 1000;
%save model (oxido-reductive pathway)
save('../models/candida_intermedia/cintGEM_oxido.mat','model')