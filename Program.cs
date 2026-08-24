using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);
var app = builder.Build();

var siteRoot = new PhysicalFileProvider(app.Environment.ContentRootPath);
app.UseDefaultFiles(new DefaultFilesOptions
{
    FileProvider = siteRoot
});
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = siteRoot
});

app.Run();
