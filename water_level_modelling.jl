
using Pkg
Pkg.activate(".")
import ArchGDAL as AG
using ProgressMeter

test_raster = AG.read("/Users/adam/Documents/GitHub/htf-nc-commuting/data/NOAA_SLR_DEM.tif")
band = AG.getband(test_raster, 1)

# fn = "/Users/adam/Documents/GitHub/htf-nc-commuting/data/NOAA_SLR_DEM.tif"
fn = "/Volumes/my_hd/htf_on_roads/noaa_elevation/carteret_test_dem.tif"
# fn = "/Volumes/my_hd/htf_on_roads/noaa_elevation/terra_noaa_mhhw_dem_1m.tif"
cutoff = 0.6
output = "./data/temporary.tif"
# output = "/Volumes/my_hd/htf_on_roads/noaa_elevation/temporary2.tif"

function cutoff_fx(x, cutoff)
    m = Matrix{UInt8}((0 .< x .<= cutoff))
    return m
end

function raster_fx(fn::String, cutoff::Real, output::String)
    ds = AG.read(fn)
    band = AG.getband(ds, 1)

    cols_v = []
    rows_v = []

    windows = AG.windows(band)

    for (cols, rows) in windows
        push!(cols_v, cols)
        push!(rows_v, rows)
    end

    AG.create(
        output,
        driver = AG.getdriver("GTiff"),
        width=AG.width(band),
        height=AG.height(band),
        nbands=1,
        dtype=UInt8,
        options=["COMPRESS=LZW"] #"BIGTIFF=YES"
    ) do dataset
        lk = ReentrantLock()
        @showprogress for i in eachindex(cols_v) # 
            lock(lk) do
                x = AG.read(band, rows_v[i], cols_v[i])
                new_x = cutoff_fx(x, cutoff)
                AG.write!(dataset, new_x, 1, rows_v[i], cols_v[i])
            end
        end

        new_band = AG.getband(dataset, 1)

        AG.setnodatavalue!(new_band, UInt8(0))
        AG.setgeotransform!(dataset, AG.getgeotransform(ds))
        AG.setproj!(dataset, AG.getproj(ds))
    end

    return "Output file written to:" * output
end
