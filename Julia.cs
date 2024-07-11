using System;
using System.Collections.Generic;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Media;

namespace ActiveSuspensionApp
{
    public static class Julia
    {



        // IMPORTS ----------------------------------------------------
        // windows 
        [DllImport("kernel32.dll")]
        static extern bool SetDllDirectory(string pathName);


        // julia
        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_symbol(string name);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_get_global(IntPtr module, IntPtr symbol);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern void jl_init_with_image(string julia_bindir, string image_relative_path);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern void jl_init_with_image__threading(string julia_bindir, string image_relative_path);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_eval_string(string str);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_call0(IntPtr function);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_call1(IntPtr function, IntPtr arg1);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_call2(IntPtr function, IntPtr arg1, IntPtr arg2);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_call3(IntPtr function, IntPtr arg1, IntPtr arg2, IntPtr arg3);

        //[DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        //public static extern IntPtr jl_new_struct(IntPtr type, IntPtr val);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_call(IntPtr function, IntPtr args, int nargs);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern int jl_array_size(IntPtr value, int dim);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_ptr_to_array(IntPtr arraytype, IntPtr data, IntPtr dims, int own_buffer);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_array_ptr(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        public static extern IntPtr jl_box_float64(double value);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        private static extern IntPtr jl_exception_occurred();

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl)]
        private static extern void jl_exception_clear();

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_string_ptr(IntPtr value);

        [DllImport("libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_typeof_str(IntPtr value);

        [DllImport(@"libjulia.dll", CallingConvention = CallingConvention.Cdecl, CharSet = CharSet.Ansi)]
        public static extern IntPtr jl_cstr_to_string(string str);


        // GC ---------------------------------------------
        public static void gc_push(IntPtr var)
        {
            jl_setindex(refs, var, var);
        }

        public static void gc_pop(IntPtr var)
        {
           jl_delete(refs, var);
        }

        // FUNCTIONS -------------------------------------
        public static IntPtr base_module;
        public static IntPtr setindex_sym;
        public static IntPtr setindex_fun;
        public static IntPtr delete_sym;
        public static IntPtr delete_fun;
        public static IntPtr setproperty_sym;
        public static IntPtr setproperty_fun;
        public static IntPtr sprint_sym;
        public static IntPtr sprint_fun;
        public static IntPtr showerror_sym;
        public static IntPtr showerror_fun;

        public static IntPtr refs;
        //public static IntPtr refval = jl_eval_string("Base.RefValue{Any}");

        public static void jl_setindex(IntPtr collection, IntPtr key, IntPtr value)
        {
            jl_call3(setindex_fun, collection, key, value);
        }

        public static void jl_delete(IntPtr collection, IntPtr key)
        {
            jl_call2(delete_fun, collection, key);
        }


        // STARTUP -------------------------------------
        public static void StartJulia(string mBinPath, string mSysImg, string? mLoadPath = null, string? mDepotPath = null)
        {


            if (mDepotPath != null)
                Environment.SetEnvironmentVariable("JULIA_DEPOT_PATH", mDepotPath);

            if (mLoadPath != null)
                Environment.SetEnvironmentVariable("JULIA_LOAD_PATH", mLoadPath);

            //NOTE: This appears to help, if the Path variable is set to a different version of Julia then the version loading from Julia installer,
            //      this will crash, so SetDllDirectory ensures the libjulia.dll will be the correct one I guess
            SetDllDirectory(mBinPath);

            jl_init_with_image__threading(mBinPath, mSysImg);


            base_module = jl_eval_string("Base");
            setindex_sym = jl_symbol("setindex!");
            setindex_fun = jl_get_global(base_module, setindex_sym);
            delete_sym = jl_symbol("delete!");
            delete_fun = jl_get_global(base_module, delete_sym);
            setproperty_sym = jl_symbol("setproperty!");
            setproperty_fun = jl_get_global(base_module, setproperty_sym);
            sprint_sym = jl_symbol("sprint");
            sprint_fun = jl_get_global(base_module, sprint_sym);
            showerror_sym = jl_symbol("showerror");
            showerror_fun = jl_get_global(base_module, showerror_sym);
            refs = jl_eval_string("refs = IdDict()");


        }

        public struct Array
        {
            public int n;
            public IntPtr ptr;
        }

        public struct Matrix
        {
            public int r;
            public int c;
            public IntPtr ptr;
        }

        public static string GetString(IntPtr ret)
        {
            try
            {

                IntPtr ptr = jl_string_ptr(ret);
                return Marshal.PtrToStringAnsi(ptr);
            }
            catch { throw; }
        }

        public static Matrix GetMatrix(IntPtr ret)
        {
            try
            {
                int r = jl_array_size(ret, 0);
                int c = jl_array_size(ret, 1);
                IntPtr ptr = jl_array_ptr(ret);
                return new Matrix() { r = r, c = c, ptr = ptr };
            }
            catch (Exception) { throw; }
        }

        public static double[,] GetFloat64Matrix(IntPtr ret)
        {
            try
            {

                Matrix m = GetMatrix(ret);

                double[] data = new double[m.r * m.c];

                Marshal.Copy(m.ptr, data, 0, m.r * m.c);

                double[,] mdata = new double[m.r, m.c];

                for (int i = 0; i < m.r; i++)
                {
                    for (int j = 0; j < m.c; j++)
                    {
                        mdata[i, j] = data[j * m.r + i];
                    }
                }

                return mdata;
            }
            catch (Exception) { throw; }

        }

        public static IntPtr SendArgs(IntPtr[] args)
        {
            int n = args.Length;
            IntPtr hdata = Marshal.AllocHGlobal(n * IntPtr.Size);

            Marshal.Copy(args, 0, hdata, n);

            return hdata;
        }

        public static IntPtr RunFunction(IntPtr fun)
        {
            jl_exception_clear();
            IntPtr x = jl_call0(fun);
            IntPtr ex_ptr = jl_exception_occurred();
            if (ex_ptr != IntPtr.Zero)
            {
                IntPtr fullerrptr = jl_call2(sprint_fun, showerror_fun, ex_ptr);
                string errmsg = GetString(fullerrptr);
                throw new Exception(errmsg);
            }

            return x;
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1)
        {
            jl_exception_clear();
            IntPtr x = jl_call1(fun, arg1);
            IntPtr ex_ptr = jl_exception_occurred();
            if (ex_ptr != IntPtr.Zero)
            {
                IntPtr fullerrptr = jl_call2(sprint_fun, showerror_fun, ex_ptr);
                string errmsg = GetString(fullerrptr);
                throw new Exception(errmsg);
            }

            return x;
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2)
        {
            jl_exception_clear();
            IntPtr x = jl_call2(fun, arg1, arg2);
            IntPtr ex_ptr = jl_exception_occurred();
            if (ex_ptr != IntPtr.Zero)
            {
                IntPtr fullerrptr = jl_call2(sprint_fun, showerror_fun, ex_ptr);
                string errmsg = GetString(fullerrptr);
                throw new Exception(errmsg);
            }

            return x;
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3)
        {
            jl_exception_clear();
            IntPtr x = jl_call3(fun, arg1, arg2, arg3);
            IntPtr ex_ptr = jl_exception_occurred();
            if (ex_ptr != IntPtr.Zero)
            {
                IntPtr fullerrptr = jl_call2(sprint_fun, showerror_fun, ex_ptr);
                string errmsg = GetString(fullerrptr);
                throw new Exception(errmsg);
            }
                
            return x;
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4 });
                return jl_call(fun, args, 4);

            }
            catch { throw; }
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4, IntPtr arg5)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4, arg5 });
                return jl_call(fun, args, 5);

            }
            catch { throw; }
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4, IntPtr arg5, IntPtr arg6)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4, arg5, arg6 });
                return jl_call(fun, args, 6);

            }
            catch { throw; }
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4, IntPtr arg5, IntPtr arg6, IntPtr arg7)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4, arg5, arg6, arg7 });

                IntPtr ret = jl_call(fun, args, 7);

                return ret;
            }
            catch { throw; }
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4, IntPtr arg5, IntPtr arg6, IntPtr arg7, IntPtr arg8)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8 });
                return jl_call(fun, args, 8);

            }
            catch
            {
                throw;
            }
        }

        public static IntPtr RunFunction(IntPtr fun, IntPtr arg1, IntPtr arg2, IntPtr arg3, IntPtr arg4, IntPtr arg5, IntPtr arg6, IntPtr arg7, IntPtr arg8, IntPtr arg9)
        {
            try
            {
                IntPtr args = SendArgs(new IntPtr[] { arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9 });
                return jl_call(fun, args, 9);

            }
            catch
            {
                throw;
            }
        }





    }
}
