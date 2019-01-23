--A layer is a table with geometries
create table lineal_groups(
  layer_name text,
  group_id int -- all lineal layers in the same group will connect through points exposed.
               -- Which point from layer is exposed depends on connectivity policy defined on layer table and point table
               -- Group 1 could be main streets layer, secondary streets layer
               -- Group 2 could be Aerial streets layer (the one that planes uses)
);
create table point_groups(
  --A point layer will join two or more lineal layer from different groups. They are transference points, like a bus stop could be, or an airport
  --It is defined that a point layer join lineal layer and not groups, it could be groups, but not.
  point_layer_name text,
  lineal_layer_name text
);


create table layers_info(
  layer_name text,
  layer text,  -- Sql to extract a layer table as specified by 'layer' table
  conn_policy integer, -- It just takes 0 or 1 values and depending of which label this record represents, it takes meaning
                       -- If this is a lineal layer
                       -- 0 to expose just start and ending point from geometry.
                       -- 1 to expose all points inside the geometry, so there could be a graph point here if another exposed
                             --point from any geometry from any lineal layer on the same group, intercepts with this point
                       -- If this is a point layer
                       -- 0 to honor lineal layers's conn_policy.
                       -- 1 to override lineal layer's conn_policy, so, if there are two points that intercepts from
                            -- the layers's geometries that this layer joins,  then there will be created a graph point
                            -- on this point no matter whether these point were inner points or edge points
  z integer  -- Way of getting z from geometry to support underway
             -- 0 to ignore z
             -- 1 will get z from geometry
             -- 2 will get z from z_start column, and z_end column. With this option only edges point will have z
);
create table layer (
  id integer,
  geom geometry,
  z_start integer,
  z_end integer
);
