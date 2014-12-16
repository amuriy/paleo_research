#!/bin/sh

# ### N1_3
# vozrast=N1_3
# tochki=N1_3_borta_pts_i2000
# pts_1km=N1_3_med_gen_pts
# vodorazd=N1_3_vod_pts
# dem=mzymta_relief_i20_dem
# mask=N1_3_segments

### N2
vozrast=N2
tochki=N2_borta_pts_sel
pts_1km=N2_med_gen_pts_not0
vodorazd=N2_vod_pts
dem=mzymta_relief_i20_dem
mask=N2_segments

# ### E
# vozrast=E
# tochki=E_borta_pts
# pts_1km=E_pts_1km_ALL_not0
# vodorazd=E_vod_pts
# dem=mzymta_relief_i20_dem
# mask=E_segments


# ### Q1
# vozrast=Q1
# tochki=Q1_borta_pts
# pts_1km=Q1_doliny_pts_vor_sel_qgis_1km_not0
# vodorazd=Q1_vod_pts
# dem=mzymta_relief_i20_dem
# mask=Q1_segments


# for vect in $tochki $pts_1km $vodorazd; do
#     g.copy vect=${vect}__edit,${vect}_backup --q
# done


vector_work() {

for map in $tochki $vodorazd; do
    for col in $(v.info -c $map --q | grep -v "cat$" | cut -d"|" -f2); do 
	v.db.dropcol $map col=$col --q > /dev/null 2>&1
    done
done

v.db.droptable -f $tochki --q > /dev/null 2>&1

v.category in=$tochki out=TMP_${tochki}_nocats opt=del --q > /dev/null 2>&1
v.category in=TMP_${tochki}_nocats out=TMP_${tochki}_newcats  --q > /dev/null 2>&1

tochki=TMP_${tochki}_newcats

v.db.addtable $tochki col="paleo_hgt double,curr_hgt double,hgt_diff double" --q > /dev/null 2>&1

v.db.droptable -f $vodorazd --q
v.db.addtable $vodorazd col="paleo_hgt double,curr_hgt double,hgt_diff double" --q > /dev/null 2>&1


g.region rast=$dem

v.what.rast vector=$vodorazd raster=$dem column=curr_hgt --q > /dev/null 2>&1

g.copy vect=$mask,TMP_${mask}_copy --q > /dev/null 2>&1
v.category in=TMP_${mask}_copy out=TMP_${mask}_copy_nocats opt=del --q > /dev/null 2>&1
v.category in=TMP_${mask}_copy_nocats out=TMP_${mask}_copy_newcats  --q > /dev/null 2>&1

v.category in=TMP_${mask}_copy_newcats opt=print type=centroid \
    | while read acat; do
    v.extract in=TMP_${mask}_copy_newcats out=TMP_${mask}_${acat} \
	list=$acat type=area --o --q > /dev/null 2>&1
done
    

for PART in $(g.mlist vect pat="TMP_${mask}_[0-9]*"); do 
    g.region rast=$dem vect=$PART
    v.what.rast vector=$tochki raster=$dem column=curr_hgt --q > /dev/null 2>&1

    for vect in $tochki $pts_1km; do
    	v.select ain=$vect atype=point bin=$PART btype=area \
    		 output=${PART}_${vect}_SEL op=overlap  --o --q > /dev/null 2>&1

	# v.info -t ${PART}_${vect}_SEL | grep 'point'
	# v.db.select ${PART}_${vect}_SEL 

    done



    ## от точек медиан до точек бортов
    v.distance from=${PART}_${tochki}_SEL from_type=point \
	       to=${PART}_${pts_1km}_SEL to_type=point \
    	       upload=to_attr column=paleo_hgt to_column=paleo_hgt \
    	       out=${PART}_${tochki}__${pts_1km}__dist --o --q > /dev/null 2>&1

    # d.vect ${PART}_${tochki}__${pts_1km}__dist
    # d.vect "${PART}_${tochki}_SEL" disp=shape,attr icon=basic/circle size=8 \
    # 	   fcol=green attrcol=paleo_hgt lcol=green xref=right yref=center lsize=12
    
    echo "DELETE FROM "${PART}_${tochki}_SEL" WHERE paleo_hgt = '0'" | db.execute
    echo "UPDATE "${PART}_${tochki}_SEL" SET hgt_diff="curr_hgt-paleo_hgt"" | db.execute

done


v.patch in=$(g.mlist vect pat="*${tochki}__dist" sep=',') \
    out=${vozrast}_median_borta_DIST --o

v.patch -e in=$(g.mlist vect pat="*${mask}*_${tochki}_SEL" sep=',') \
    out=${vozrast}_borta_PTS_ALL --o

tochki=${vozrast}_borta_PTS_ALL


## от ВСЕХ точек бортов до водоразделов
v.distance from=$vodorazd from_type=point to=${tochki} to_type=point \
    upload=to_attr column=hgt_diff to_column=hgt_diff \
    out=N2_borta_vod_DIST --o > /dev/null 2>&1

## получаем высоты палеовозвышенностей 
echo "UPDATE "$vodorazd" SET paleo_hgt="curr_hgt-hgt_diff"" | db.execute
echo "DELETE FROM "$vodorazd" WHERE paleo_hgt IS NULL" | db.execute


for map in $tochki $pts_1km $vodorazd; do
    g.copy vect=$map,TMP_${map}_todem --q
    
    for col in $(v.info -c TMP_${map}_todem --q \
    	| grep -v "cat$\|paleo_hgt" | cut -d"|" -f2); do 
    	v.db.dropcol TMP_${map}_todem col=$col --q > /dev/null 2>&1
    done
done


v.patch -e in=$(g.mlist vect pat="TMP_*_todem" sep=',') out=${vozrast}_PTS_TODEM --q


## EDITS if needed
v.edit ${vozrast}_PTS_TODEM tool=delete \
       where="paleo_hgt <= '0' OR paleo_hgt IS NULL" cats=0-99999
echo "DELETE FROM ${vozrast}_PTS_TODEM WHERE paleo_hgt <= '0' OR paleo_hgt IS NULL" | db.execute

# if [ $vozrast = 'N2' ]; then
# echo "DELETE FROM ${vozrast}_PTS_TODEM WHERE cat = 586 OR cat = 587 \
# OR cat = 1365 OR cat = 1053 OR cat = 1392 OR cat = 1035" | db.execute
# v.edit ${vozrast}_PTS_TODEM tool=delete cat=586,587,1365,1053,1392,1035
# fi

}








raster_work() {

g.region rast=$dem res=50 --q 

r.mask -r
r.mask in=mzymta_mask --q

v.to.rast in=${vozrast}_PTS_TODEM type=point out=TMP_pts_todem use=attr column=paleo_hgt --o > /dev/null 2>&1

# /home/amuriy/bin/grass_addons_bin/r.surf.nnbathy in=TMP_pts_todem out=paleo_dem alg=nn --o
r.surf.nnbathy in=TMP_pts_todem out=paleo_dem alg=nn --o --q > /dev/null 2>&1

r.colors paleo_dem color=elevation --q > /dev/null 2>&1

r.resample in=paleo_dem out=paleo_dem.cut --q
g.rename rast=paleo_dem.cut,paleo_dem --o --q

r.neighbors in=paleo_dem out=paleo_dem.filt size=3 --o --q > /dev/null 2>&1

r.shaded.relief paleo_dem.filt shadedmap=paleo_dem.shaded zmult=2 --o --q > /dev/null 2>&1

r.contour in=paleo_dem.filt out=paleo_dem_cont_i100 step=100 --o --q > /dev/null 2>&1
# r.contour in=paleo_dem.filt out=paleo_dem_cont_i50 step=50 --o
# r.contour in=paleo_dem.filt out=paleo_dem_cont_i10 step=10 --o

r.mask -r --q > /dev/null 2>&1
}


eval "$(g.gisenv)"
eval "$(g.findfile mapset="$MAPSET" element=vector file="${vozrast}_PTS_TODEM")"
if [ ! "$file" ]; then
    echo "==================== vector_work ===================="
    echo ""
    vector_work

    echo "==================== raster_work ===================="
    echo ""
    raster_work

else
    echo ""
    echo "==================== raster_work ===================="
    echo ""
    raster_work

fi





### clean temp data
g.mremove -f vect="TMP_*" rast="TMP_*" --q > /dev/null 2>&1
g.region -d > /dev/null 2>&1











