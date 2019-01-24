--A layer is a table with geometries
drop table if exists grupos_lineales;
create table grupos_lineales(
  nombre_capa text,
  identificador_grupo int -- all lineal layers in the same group will connect through points exposed.
               -- Which point from layer is exposed depends on connectivity policy defined on layer table and point table
               -- Group 1 could be main streets layer, secondary streets layer
               -- Group 2 could be Aerial streets layer (the one that planes uses)
);
drop table if exists grupos_puntuales;
create table grupos_puntuales(
  --A point layer will join two or more lineal layer from different groups. They are transference points, like a bus stop could be, or an airport
  --It is defined that a point layer join lineal layer and not groups, it could be groups, but not.
  nombre_capa_puntual text,
  nombre_capa_lineal text
);

drop table if exists informacion_capas;
create table informacion_capas(
  nombre_capa text,
  capa text,  -- Sql to extract a layer table as specified by 'layer' table
  politica_conectividad integer, -- It just takes 0 or 1 values and depending of which label this record represents, it takes meaning
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
drop table if exists capa_lineal;
create table capa_lineal (
  identificador integer,
  geometria geometry,
  z_inicial float,
  z_end float
);
drop table if exists capa_puntual;
create table capa_puntual (
  identificador integer,
  geometria geometry,
  z float
);

create or REPLACE function pgr_wrap_createtopology_multimodal (p_lineal_groups     text, p_puntual_groups     text, p_layers    text,
                                                          p_graph_lines_table text, p_graph_lines_schema text, p_tolerance FLOAT,
                                                          out ip_out_d integer, out p_out_layname text, out p_out_error text)
  returns setof record as
$$
declare
  v_lineal_groups jsonb default '{}'::jsonb;
  v_puntual_groups jsonb default '{}'::jsonb;
  v_layers jsonb default '{}'::jsonb;
  v_group int;
  v_layer_name text;
  v_point_name text;
  v_sql text;
  v_pconn int;
  v_z int;
begin
  raise notice 'here';
  for v_layer_name, v_group in EXECUTE p_lineal_groups loop
    if v_lineal_groups->v_group is null then
      v_lineal_groups = jsonb_set(v_lineal_groups,('{'||v_group||'}')::text[],'[]'::jsonb);
    end if;

    v_lineal_groups = jsonb_insert(v_lineal_groups,('{'||v_group||',0}')::text[],('"'||v_layer_name||'"')::jsonb);
  end loop;

  for v_point_name, v_layer_name in EXECUTE p_puntual_groups loop
    if v_puntual_groups->v_point_name is null then
      v_puntual_groups = jsonb_set(v_puntual_groups,('{'||v_point_name ||'}'):: text[],'[]'::jsonb);
    end if;
    v_puntual_groups = jsonb_insert(v_puntual_groups,('{'||v_point_name ||',0}')::text[],('"'||v_layer_name||'"')::jsonb);
  end loop;

  for v_layer_name, v_sql, v_pconn, v_z in EXECUTE p_layers loop
    v_layers = jsonb_set(v_layers,('{'||v_layer_name||'}')::text[],('{'
      || '"sql"   :"'|| v_sql   || '"' ||
         ',"pconn":"'|| v_pconn || '"' ||
         ',"zconn":"'|| v_z     || '"' ||
         '}')::jsonb);
  end loop;

  raise notice 'lineal_group: %', v_lineal_groups;
  raise notice 'puntual_group: %', v_puntual_groups;
  raise notice 'v_layers: %', v_layers;

  return query select * from pgr_createtopology_multimodal(v_lineal_groups, v_puntual_groups, v_layers, p_graph_lines_table, p_graph_lines_schema, p_tolerance);
end;

$$ LANGUAGE plpgsql;

--adding test 2lines-1points-1 z-0   from pgTapTest
drop table if exists tabla_pruebas_l1;
create table tabla_pruebas_l1(
  geometria geometry('linestringz',4326),
  identificador integer primary key,
  z_inicial float default 0,
  z_final float default 0
);

insert into tabla_pruebas_l1 VALUES ('SRID=4326;linestring(5 0 0,10 10 0, 13 10 0, 15 10 0)',1);
insert into tabla_pruebas_l1 VALUES ('SRID=4326;linestring(0 0 0, 10 10 0)',2);
insert into tabla_pruebas_l1 VALUES ('SRID=4326;linestring(10 10 0, 10 0 0)',3);
insert into tabla_pruebas_l1 VALUES ('SRID=4326;linestring(8 0 0, 10 10 0)',4);
insert into tabla_pruebas_l1 VALUES ('SRID=4326;linestring(8 0 0, 8 10 0, 10 10 0)', 5);
insert into tabla_pruebas_l1 values ('SRID=4326;linestring(7 12 0, 13 10 0, 14 8 0)', 6);

--for test z
insert into tabla_pruebas_l1 values ('SRID=4326;linestring(15 14 50, 15 10 50, 15 8 50)', 7); --overpass over point(15 10 0)
insert into tabla_pruebas_l1 values ('SRID=4326;linestring(15 16 35, 15 14 50)', 8); -- z connects with edge points
insert into tabla_pruebas_l1 values ('SRID=4326;linestring(13 16 35, 15 14 50, 13 14 50)', 9); -- z connects with interior points

drop table if exists tabla_pruebas_l2;
create table tabla_pruebas_l2(
  geometria geometry('linestringz',4326),
  identificador integer primary key,
  z_inicial float default 0,
  z_final float default 0
);

insert into tabla_pruebas_l2 values ('SRID=4326;linestring(13 18 35, 13 16 35, 7 12 0)', 1);
insert into tabla_pruebas_l2 values ('SRID=4326;linestring(15 18 0, 15 16 35, 17 18 0)', 2);

drop table if exists tabla_pruebas_p1;
create TABLE tabla_pruebas_p1(
  geometria geometry('pointz',4326),
  identificador integer primary key,
  z float default 0

);

insert into tabla_pruebas_p1 values('SRID=4326;point(10 10 0)',1);
insert into tabla_pruebas_p1 values('SRID=4326;point(10 0 0)',2);
insert into tabla_pruebas_p1 values('SRID=4326;point(8 10 0)',3);
insert into tabla_pruebas_p1 values('SRID=4326;point(8 0 0)',4);
insert into tabla_pruebas_p1 values('SRID=4326;point(5 0 0)',5);
insert into tabla_pruebas_p1 values('SRID=4326;point(0 0 0)',6);
insert into tabla_pruebas_p1 values('SRID=4326;point(7 12 0)',7);

--for test z
insert into tabla_pruebas_p1 values('SRID=4326;point(15 10 0)',8);
insert into tabla_pruebas_p1 values('SRID=4326;point(13 14 50)',9);  --edge point  of layer 2
insert into tabla_pruebas_p1 values('SRID=4326;point(15 16 35)',10); --interior point of layer 2
insert into tabla_pruebas_p1 values('SRID=4326;point(15 8 50)',11);

--for test connectivity with 2nd layer
insert into tabla_pruebas_p1 values('SRID=4326;point(14 8 0)',12);
insert into tabla_pruebas_p1 values('SRID=4326;point(13 18 35)',13);
insert into tabla_pruebas_p1 values('SRID=4326;point(15 18 0)',14);

insert into grupos_lineales values('capaLineal-1',1),('capaLineal-2',2);
insert into grupos_puntuales values('capaPuntual-1','capaLineal-1'),('capaPuntual-1','capaLineal-2');
insert into informacion_capas values('capaLineal-1','select identificador as id, geometria as the_geom, z_inicial as z_start, z_final as z_end from tabla_pruebas_l1',1,0),
                              ('capaLineal-2','select identificador as id, geometria as the_geom, z_inicial as z_start, z_final as z_end from tabla_pruebas_l2',1,0),
                              ('capaPuntual-1','select identificador as id, geometria as the_geom, z from tabla_pruebas_p1',1,0);

SELECT count(*) from  pgr_wrap_createtopology_multimodal(
  'select * from grupos_lineales',
  'select * from grupos_puntuales',
  'select * from informacion_capas',
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
