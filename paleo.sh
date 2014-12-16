#!/bin/sh

# tochki=FINAL__N1_3_borta_pts_sel
# pts_1km=FINAL__pts_1km
# vodorazd=FINAL__N1_3_vod_pts
# dem=mzymta_relief_i20_dem


tochki=FINAL__N1_3_borta_pts_sel
pts_1km=FINAL__pts_1km
vodorazd=FINAL__N1_3_vod_pts
dem=mzymta_relief_i20_dem
vect_mask=FINAL__vect_mask1
MASK=MASK_1


for vect in $tochki $pts_1km $vodorazd; do
    v.select ain=$vect bin=$vect_mask output=${MASK}_${vect}_SEL op=overlap  --o
done

tochki=${MASK}_${tochki}_SEL
pts_1km=${MASK}_${pts_1km}_SEL
vodorazd=${MASK}_${vodorazd}_SEL


pts_to_dem=${MASK}_pts_to_dem
paleo_dem=${MASK}_paleo_dem

for vect in $tochki $pts_1km $vodorazd; do
    g.copy vect=$vect,${vect}_backup --o
done


for map in $tochki $vodorazd; do
    for col in $(v.info -c $map --q | grep -v "cat$" | cut -d"|" -f2); do 
	v.db.dropcol $map col=$col
    done
done


v.db.addcol $tochki col="paleo_hgt double,curr_hgt double,hgt_diff double"

v.db.droptable -f $vodorazd --q
v.db.addtable $vodorazd col="paleo_hgt double,curr_hgt double,hgt_diff double"


g.region rast=$dem vect=$vect_mask

v.what.rast vector=$tochki raster=$dem column=curr_hgt 


v.distance from=$tochki from_type=point to=$pts_1km to_type=point upload=to_attr column=paleo_hgt to_column=paleo_hgt out=${tochki}__${pts_1km}__dist --o
echo "UPDATE "$tochki" SET paleo_hgt=431 WHERE cat = 186" | db.execute
echo "UPDATE "$tochki" SET paleo_hgt=431 WHERE cat = 110" | db.execute
echo "UPDATE "$tochki" SET paleo_hgt=442 WHERE cat = 111" | db.execute

echo "DELETE FROM "$tochki" WHERE paleo_hgt = '0'" | db.execute
echo "UPDATE "$tochki" SET hgt_diff="curr_hgt-paleo_hgt"" | db.execute


v.what.rast vector=$vodorazd raster=$dem column=curr_hgt 

v.distance from=$vodorazd from_type=point to=$tochki to_type=point upload=to_attr column=hgt_diff to_column=hgt_diff out=${vodorazd}__${tochki}__dist --o 

echo "UPDATE "$vodorazd" SET paleo_hgt="curr_hgt-hgt_diff"" | db.execute
echo "DELETE FROM "$vodorazd" WHERE paleo_hgt IS NULL" | db.execute


for maps in $tochki $pts_1km $vodorazd; do
    g.copy vect=$maps,${maps}__edit --o
done

g.mlist vect pat="*__edit" | while read map; do 
    for col in curr_hgt hgt_diff; do
	v.db.dropcol $map col=$col
    done
done

for cols in lcat cat_along dist_along; do
    v.db.dropcol ${pts_1km}__edit col=$cols
done

for maps in $(g.mlist vect pat="${MASK}*__edit" sep=","); do
    v.patch -e in=$maps out=$pts_to_dem --o
done

echo "DELETE FROM pts_to_dem WHERE paleo_hgt <= '0' OR paleo_hgt IS NULL" | db.execute



####################
### raster work

# g.region res=50

# r.mask in=mzymta_mask

# v.to.rast in=$pts_to_dem type=point out=$pts_to_dem use=attr column=paleo_hgt --o

# # /home/amuriy/bin/grass_addons_bin/r.surf.nnbathy in=pts_to_dem out=paleo_dem alg=nn --o
# r.surf.nnbathy in=$pts_to_dem out=$paleo_dem alg=nn --o

# r.colors paleo_dem color=elevation

# r.resample in=$paleo_dem out=${paleo_dem}_cut
# g.rename rast=${paleo_dem}_cut,${paleo_dem} --o

# r.neighbors in=$paleo_dem out=${paleo_dem}.filt size=3 --o

# r.shaded.relief ${paleo_dem}.filt shadedmap=${paleo_dem}.shaded zmult=2 --o

# r.contour in=${paleo_dem}.filt out=${paleo_dem}_cont_i100 step=100 --o
# # r.contour in=paleo_dem.filt out=paleo_dem_cont_i50 step=50 --o
# # r.contour in=paleo_dem.filt out=paleo_dem_cont_i10 step=10 --o

# r.mask -r





