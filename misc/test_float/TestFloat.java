
//
// A little stand-alone program to test floating-point precision
// issues.  This uses the apfloat library from 
// http://www.apfloat.org/apfloat_java/
//
//

import org.apfloat.*;

public class TestFloat {

    public static void main(String[] args) {
        Apcomplex x 
            = new Apcomplex("(-1.23400000000000000, -5.67800000000000000)");
        Apcomplex base = new Apcomplex("10.00000000000000");
        x = ApcomplexMath.pow(base, x);
        System.out.println(x + " to " + x.precision() + " radix digits");
    }
}
