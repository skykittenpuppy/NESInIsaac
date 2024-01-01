using System;
using System.IO;
using System.Collections.Generic;

namespace ConvertNES
{
    class Program
    {
        static void Main(string[] args)
        {
            Console.WriteLine("Enter the name of the rom to convert (eg 'The Legend of Zelda' = roms/The Legend of Zelda.nes)");
            string fileName = Console.ReadLine();
            byte[] rom = File.ReadAllBytes("roms/"+fileName+".nes");
            //List<int> ints = new List<int>();
            string result = "return {";

            foreach (byte Byte in rom)
            {
                //ints.Add(Byte);
                result += Byte.ToString()+", ";
            }
            result += "}";

            Console.WriteLine(result);
            File.WriteAllLines("NES ROM.lua", new string[] {result});
            Console.WriteLine("Completed. Hit ENTER to close.");
            Console.ReadLine();
        }
    }
}
