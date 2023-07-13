function [ds_out,msg] = struct2ds(ds_struct)
%STRUCT2DS Convert a structure into a dataset object.
% Attempts to convert fields of a structure (in) into corresponding fields
% in a DataSet object (out). Field names and contents should be the same as
% those in a DataSet object. Some fields (such as history and moddate)
% cannot be copied over and will be ignored.
%
% One critical difference between standard DataSet object field formats and
% what is expected in the input structure is that the fields: label, class,
% axisscale, title, and include are cells with three modes (instead of the
% usual two) where the indices representing:
%    {mode, val_or_name, set}
% The first and thrid dimensions are the same as with the standard indices
% for these fields, but the second is the value "1" for the actual value
% for the field and "2" for the name (usually stored in the DataSet object
% in a field named "____name", such as "classname")
%
% INPUT:
%    in = Structure containing one or more fields appropriate for a DataSet
%         object. See the DataSet object documentation for information and
%         format of these fields
% OUTPUTS:
%   out = DataSet object created from the contents of the input structure.
%   msg = Text of any error/warning messages discovered during the
%          conversion. Returned as empty if no errors were found.
%
% If only one output is requested, any discovered errors/warnings will be
% displayed on the screen.
%
%I/O: [ds_out,msg] = struct2ds(ds_struct)
%
%See also: DATASET, EDITDS

%Copyright © Eigenvector Research, Inc. 2006
%Licensee shall not re-compile, translate or convert "M-files" contained
% in PLS_Toolbox for use with any software other than MATLAB®, without
% written permission from Eigenvector Research, Inc.

msg = {};

%prepare empty DSO
ds_out = dataset;

%not a structure? try making a dataset out of what they passed
if ~isstruct(ds_struct)
  ds_out.data = ds_struct;
  return
end

%check for fields we don't know how to place
fields = {  'name'  'type'  'author'  'date'  'moddate'  'imagesize'  'imagemode'  ...
  'data'  'label'  'axisscale'  'imageaxisscale' 'title'  'class' 'include' ...
  'description'  'userdata'  'datasetversion'  'history' 'uniqueid'};
namefields = {'labelname' 'axisscalename' 'imageaxisscalename' 'axistypename' 'titlename' 'classname'};
if str2num(ds_out.datasetversion)>=5.0;
  %DSO v5 includes a few new fields
  fields = [fields {'classlookup' 'axistype' 'imageaxistype'}];
end

nomatch = setdiff(fieldnames(ds_struct),[fields namefields]);
if ~isempty(nomatch)
  msg = [msg {'Some fields in the input structure do not have matching fields in a DataSet object and have been discarded.'} ...
    {sprintf('   - %s\n',nomatch{:})}];
end

explictnamefields = any(ismember(fieldnames(ds_struct),namefields));
if ~explictnamefields
  %so far, it appears the name fields are mixed in with the label content
  for labelfield = {'label' 'class' 'axisscale'};
    if isfield(ds_struct,labelfield{:});
      val = ds_struct.(labelfield{:});
      if ndims(val)>2
        break;  %found at least one which is expilitly n-way (includes names)
      elseif size(val,2)>1
        if any(~cellfun('isclass',val(:,2),'char')) | any(cellfun('size',val(:,2),1)>1)
          %found something in column 2 which does NOT appear to be a name, we
          %must assume they have name fields explictly (but all are empty)
          explictnamefields = 1;
          break;
        end
      end
    end
  end
end
discarded_invalid = {};  %holds the list of could-not-convert fieldnames

%copy these over directly
fields = {'name' 'author' 'data' 'type' 'description' 'userdata'};
if str2num(ds_out.datasetversion)>=4.0 & isfield(ds_struct,'type') & strcmp(ds_struct.type,'image')
  %copy image info (if image mode and is available for the DSO version)
  fields = [fields {'imagesize' 'imagemode'}];
end
if isfield(ds_struct,'data');
  try
    if ischar(ds_struct.data);
      %try to force data to be numeric
      ds_struct.data = str2num(ds_struct.data);
    end
  end
  if isempty(ds_struct.data)
    error('Data field evaluates to empty (check for invalid characters).')
  end
end

for f = fields;
  if isfield(ds_struct,f{:})
    try
      ds_out = setfield(ds_out,f{:},getfield(ds_struct,f{:}));
    catch
      discarded_invalid = [discarded_invalid f];
    end
  end
end

%copy these over specially
fields = {'label' 'axisscale' 'title' 'class' 'include'};
if str2num(ds_out.datasetversion)>=5.0;
  %DSO v5 includes a few new fields
  fields = [fields {'classlookup' 'axistype'}];
end
discarded_notcell = {};
for f = fields;
  if isfield(ds_struct,f{:})
    val = getfield(ds_struct,f{:});
    if ~iscell(val);
      discarded_notcell = [discarded_notcell f];
      continue;
    end

    setmode = 2;      %if name fields are given explictly, sets are mode 2
    if ~explictnamefields & ~ismember(f{:},{'axistype','classlookup'})
      %if name fields are NOT given explictly, they are assumed
      %mixed in with mode 2 of these fields. Therefore mode 3 is sets.
      % (EXCEPT: axistype and classlookup in which mode 2 is ALWAYS sets
      setmode = 3;
    end
    if strcmp(f{:},'include')
      val = val(:);  %make it a column vector ALWAYS
      val = val(1:ndims(ds_out.data));
    end

    for mode = 1:size(val,1);
      for set = 1:size(val,setmode);
        %copy first column of cell into field itself
        try
          S   = substruct('.',f{:},'{}',{mode,set});
          subval = nindex(val,{mode set},[1 setmode]);
          ds_out = subsasgn(ds_out,S,subval{1});
        catch
          discarded_invalid = [discarded_invalid f];
        end
        if ~explictnamefields
          if size(val,2)>1;
            %copy second column of cell into ____name
            try
              if strcmp(f{:},'include'); continue; end  %skip this for include
              S   = substruct('.',[f{:} 'name'],'{}',{mode,set});
              ds_out = subsasgn(ds_out,S,val{mode,2,set});
            catch
              discarded_invalid = [discarded_invalid {[f{:} 'name']}];
            end
          end
        else
          %copy name fields explictly
          if ismember(f{:},{'axistype','classlookup','include'}); continue; end  %skip this for some fields
          try
            nameval = getfield(ds_struct,[f{:} 'name']);
          catch
            nameval = {};
          end
          try
            S   = substruct('.',[f{:} 'name'],'{}',{mode,set});
            ds_out = subsasgn(ds_out,S,nameval{mode,set});
          catch
            discarded_invalid = [discarded_invalid {[f{:} 'name']}];
          end

        end
      end
    end
  end
end

%give notes if something went wrong
if ~isempty(discarded_notcell);
  msg = [msg {'Some fields were expected to be cells but were not.' 'These fields have been discarded.'} ...
    {sprintf('   - %s\n',discarded_notcell{:})}];
end
if ~isempty(discarded_invalid);
  msg = [msg {'Some fields were not in the correct format for a DataSet object and have been discarded.'} ...
    {sprintf('   - %s\n',discarded_invalid{:})}];
end

%handle messages
if ~isempty(msg);
  msg = [msg {'Please see the documentation for the DataSet object to learn more about the correct format for these fields'}];

  %show messages (if not requested as output)
  if nargout <2
    disp(sprintf('%s\n',msg{:}));
  end
end
end