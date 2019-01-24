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
create table lineal_layer (
  id integer,
  geom geometry,
  z_start float,
  z_end float
);
create table point_layer (
  id integer,
  geom geometry,
  z float
);

--adding test 2lines-1points-1 z-0   from pgTapTest
drop table test_table_l1;
create table test_table_l1(
  geom geometry('linestringz',4326),
  id integer primary key,
  z_start float default 0,
  z_end float default 0
);

insert into test_table_l1 VALUES ('SRID=4326;linestring(5 0 0,10 10 0, 13 10 0, 15 10 0)',1);
insert into test_table_l1 VALUES ('SRID=4326;linestring(0 0 0, 10 10 0)',2);
insert into test_table_l1 VALUES ('SRID=4326;linestring(10 10 0, 10 0 0)',3);
insert into test_table_l1 VALUES ('SRID=4326;linestring(8 0 0, 10 10 0)',4);
insert into test_table_l1 VALUES ('SRID=4326;linestring(8 0 0, 8 10 0, 10 10 0)', 5);
insert into test_table_l1 values ('SRID=4326;linestring(7 12 0, 13 10 0, 14 8 0)', 6);

--for test z
insert into test_table_l1 values ('SRID=4326;linestring(15 14 50, 15 10 50, 15 8 50)', 7); --overpass over point(15 10 0)
insert into test_table_l1 values ('SRID=4326;linestring(15 16 35, 15 14 50)', 8); -- z connects with edge points
insert into test_table_l1 values ('SRID=4326;linestring(13 16 35, 15 14 50, 13 14 50)', 9); -- z connects with interior points

drop table test_table_l2;
create table test_table_l2(
  geom geometry('linestringz',4326),
  id integer primary key,
  z_start float default 0,
  z_end float default 0
);

insert into test_table_l2 values ('SRID=4326;linestring(13 18 35, 13 16 35, 7 12 0)', 1);
insert into test_table_l2 values ('SRID=4326;linestring(15 18 0, 15 16 35, 17 18 0)', 2);

drop table test_table_p1;
create TABLE test_table_p1(
  geom geometry('pointz',4326),
  id integer primary key,
  z float default 0

);

insert into test_table_p1 values('SRID=4326;point(10 10 0)',1);
insert into test_table_p1 values('SRID=4326;point(10 0 0)',2);
insert into test_table_p1 values('SRID=4326;point(8 10 0)',3);
insert into test_table_p1 values('SRID=4326;point(8 0 0)',4);
insert into test_table_p1 values('SRID=4326;point(5 0 0)',5);
insert into test_table_p1 values('SRID=4326;point(0 0 0)',6);
insert into test_table_p1 values('SRID=4326;point(7 12 0)',7);

--for test z
insert into test_table_p1 values('SRID=4326;point(15 10 0)',8);
insert into test_table_p1 values('SRID=4326;point(13 14 50)',9);  --edge point  of layer 2
insert into test_table_p1 values('SRID=4326;point(15 16 35)',10); --interior point of layer 2
insert into test_table_p1 values('SRID=4326;point(15 8 50)',11);

--for test connectivity with 2nd layer
insert into test_table_p1 values('SRID=4326;point(14 8 0)',12);
insert into test_table_p1 values('SRID=4326;point(13 18 35)',13);
insert into test_table_p1 values('SRID=4326;point(15 18 0)',14);

insert into lineal_groups values('linealLayer-1',1),('linealLayer-2',2);
insert into point_groups values('pointLayer-1','linealLayer-1'),('pointLayer-1','linealLayer-2');
insert into layers_info values('linealLayer-1','select id, geom, z_start, z_end from test_table_l1',1,0),
                              ('linealLayer-2','select id, geom, z_start, z_end from test_table_l2',1,0),
                              ('pointLayer-1','select id, geom, z from test_table_p1',1,0);

SELECT count(*) from  pgr_createtopology_multimodal(
  'select * from lineal_groups',
  'select * from point_groups',
  'select * from layers_info',
  'graph_lines',
  'public',
  0.000001
);
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_l' ||
   'ines',
   (select id from graph_lines_pt where id_geom =6 ),
   (select id from graph_lines_pt where id_geom =4 )
);
--test2
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =6 ),
   (select id from graph_lines_pt where id_geom =2 )
);

--test3
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =6 ),
   (select id from graph_lines_pt where id_geom =5 )
 );

--test4 as
select count(*) from graph_lines_pt where id_geom = 3;
--test5 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =2 ),
   (select id from graph_lines_pt where id_geom =3 )
 );
--test6 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =7 ),
   (select id from graph_lines_pt where id_geom =5 )
 );

--test7 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =7 ),
   (select id from graph_lines_pt where id_geom =6 )
 );
--test8 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =11 ),
   (select id from graph_lines_pt where id_geom =1 )
);
--test9 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =11 ),
   (select id from graph_lines_pt where id_geom =9 )
 );
--test10 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =10 ),
   (select id from graph_lines_pt where id_geom =9 )
 );
--test11 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =13 ),
   (select id from graph_lines_pt where id_geom =12 )
 );
--test12 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =13 ),
   (select id from graph_lines_pt where id_geom =9 )
 );
--test13 as
select count(*) from pgr_dijkstra(
   'select id, source, target, 0 as cost, 0 as reverse_cost from graph_lines',
   (select id from graph_lines_pt where id_geom =14 ),
   (select id from graph_lines_pt where id_geom =9 )
);