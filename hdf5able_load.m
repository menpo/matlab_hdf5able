function output = hdf5able_load(filename, varargin)

if (nargin > 2)
    error('Too many args, only supply filename and (optionally) mode');
end

if nargin == 2
    mode = varargin{1};
    if ~(strcmp(mode, 'struct') || strcmp(mode, 'map'))
         error('arg2 must be ''struct'' or ''map''');
    end
else
    mode = 'struct';  % default to struct with mangling
end


info = h5info(filename);
% assumes that there is one top level group, should check for /hdf5able
output = hdf5able_load_type(filename, info.Groups(1), mode);
end


function output = hdf5able_load_type(filename, node, mode)

type = find_attribute(node.Attributes, 'type');
% string attributes actually load as cells of size 1x1...
type = type{1};

switch type
    case {'ndarray', 'unicode', 'pathlib.Path'}
        output = hdf5able_load_dataset(filename, node);
    case {'list', 'tuple'}
        output = hdf5able_load_cell(filename, node, mode);
    case {'dict', 'HDF5able'}
        output = hdf5able_load_dict(filename, node, mode);
    case 'Number'
        output = hdf5able_load_number(node);
    case 'bool'
        output = hdf5able_load_bool(node);
    case 'NoneType'
        output = hdf5able_load_none();
    otherwise
        error(['Cannot load hdf5able type ''' type '''']);
end

end


function output = hdf5able_load_cell(filename, node, mode)

output = cell(1, length(node.Groups));

for i = 1:length(node.Groups)
    group = node.Groups(i);
    split_name = strsplit(group.Name, '/');
    index = str2num(split_name{end}) + 1;
    output{index} = hdf5able_load_type(filename, group, mode);
end

for i = 1:length(node.Datasets)
    dset = node.Datasets(i);
    index = str2num(dset.Name) + 1;
    dset.Name = [node.Name '/' dset.Name];
    output{index} = hdf5able_load_type(filename, dset, mode);
end

end


function output = hdf5able_load_dict(filename, node, mode)

if strcmp(mode, 'struct')
    output = struct();
    is_struct = true;
elseif strcmp(mode, 'map')
    output = containers.Map();
    is_struct = false;
else
    error('dict mode must be ''struct'' or ''map''');
end

n_groups = length(node.Groups);
n_dsets = length(node.Datasets);

% go through all groups and datasets to get all names found
names = cell(1, n_groups + n_dsets);

for i = 1:length(node.Groups)
    group = node.Groups(i);
    name = strsplit(group.Name, '/');
    name = name{end};
    names{i} = name;
end

for i = 1:length(node.Datasets)
    names{i + n_groups} = node.Datasets(i).Name;
end

if is_struct
    % need to mangle names for structs
    names = matlab.lang.makeValidName(names);
    names = matlab.lang.makeUniqueStrings(names, {}, namelengthmax);
end

for i = 1:length(node.Groups)
    group = node.Groups(i);
    name = names{i};
    if is_struct
        output.(name) = hdf5able_load_type(filename, group, mode);
    else
        output(name) = hdf5able_load_type(filename, group, mode);
    end
end

for i = 1:length(node.Datasets)
    dset = node.Datasets(i);
    name = names{i + n_groups};
    % reset the dataset name to a 'full' name qualifier
    dset.Name = [node.Name '/' dset.Name];
    if is_struct
        output.(name) = hdf5able_load_type(filename, dset, mode);
    else
        output(name) = hdf5able_load_type(filename, dset, mode);
    end
end

end


function output = hdf5able_load_dataset(filename, node)
output = h5read(filename, node.Name);
end


function output = hdf5able_load_number(node)
output = find_attribute(node.Attributes, 'number_value');
end


function output = hdf5able_load_bool(node)
output = strcmp(find_attribute(node.Attributes, 'bool_value'), 'TRUE');
end


function output = hdf5able_load_none()
output = [];
end
